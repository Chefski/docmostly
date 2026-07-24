import Foundation
import Observation

@MainActor
@Observable
final class DocumentSession {
    let key: DocumentStoreKey
    @ObservationIgnored let kernel: any DocumentKernel
    @ObservationIgnored private let localPeer: DocumentLocalPersistencePeer
    @ObservationIgnored private let indexer: any DocumentUpdateIndexer
    @ObservationIgnored private let compactionPolicy: DocumentCompactionPolicy
    @ObservationIgnored private var snapshotContinuations: [
        UUID: AsyncStream<NativeEditorCRDTDocumentSnapshot>.Continuation
    ] = [:]
    @ObservationIgnored private var isCompacting = false
    @ObservationIgnored private var retainedDraftTitle: String?
    @ObservationIgnored private var retainedDraft: ProseMirrorDocument?
    @ObservationIgnored private(set) var initialSnapshot: NativeEditorCRDTDocumentSnapshot?
    @ObservationIgnored private(set) var restoredLocalState = false
    @ObservationIgnored private(set) var isOpen = false
    @ObservationIgnored private(set) var syncCoordinator: NativeEditorCRDTSyncCoordinator?

    init(
        key: DocumentStoreKey,
        kernel: any DocumentKernel,
        localPeer: DocumentLocalPersistencePeer,
        indexer: any DocumentUpdateIndexer,
        compactionPolicy: DocumentCompactionPolicy
    ) {
        self.key = key
        self.kernel = kernel
        self.localPeer = localPeer
        self.indexer = indexer
        self.compactionPolicy = compactionPolicy
    }

    var documentEngine: any NativeEditorCRDTDocumentEngine {
        kernel.documentEngine
    }

    func open(title: String) async throws {
        guard isOpen == false else { return }
        try await migrateLegacyStateIfNeeded()
        var storedState = try await localPeer.load(key)
        initialSnapshot = try await restore(storedState)
        retainedDraftTitle = storedState.retainedDraftTitle
        retainedDraft = storedState.retainedDraft
        if let retainedDraft {
            if storedState.hasLocalState {
                initialSnapshot = try await promoteRetainedDraft() ?? initialSnapshot
            } else {
                initialSnapshot = NativeEditorCRDTDocumentSnapshot(
                    title: retainedDraftTitle ?? title,
                    document: NativeEditorDocument(proseMirrorDocument: retainedDraft)
                )
            }
            storedState = try await localPeer.load(key)
        }
        restoredLocalState = storedState.hasLocalState
        syncCoordinator = makeSyncCoordinator()
        isOpen = true
    }

    func snapshots() -> AsyncStream<NativeEditorCRDTDocumentSnapshot> {
        let id = UUID()
        let pair = AsyncStream.makeStream(of: NativeEditorCRDTDocumentSnapshot.self)
        snapshotContinuations[id] = pair.continuation
        if let initialSnapshot {
            pair.continuation.yield(initialSnapshot)
        }
        pair.continuation.onTermination = { [weak self] _ in
            Task { @MainActor in
                self?.snapshotContinuations[id] = nil
            }
        }
        return pair.stream
    }

    func markRemoteConnected() async {
        try? await localPeer.markConnected(key)
    }

    func retainDraft(title: String, document: ProseMirrorDocument) async throws {
        try await localPeer.retainDraft(document, title: title, key: key)
        retainedDraftTitle = title
        retainedDraft = document
    }

    func clearRetainedDraft() async {
        try? await localPeer.clearRetainedDraft(key)
        retainedDraftTitle = nil
        retainedDraft = nil
    }

    func hasPendingSynchronization() async throws -> Bool {
        if retainedDraft != nil {
            return true
        }
        return try await localPeer.pendingLocalUpdates(key).isEmpty == false
    }
}

private extension DocumentSession {
    func makeSyncCoordinator() -> NativeEditorCRDTSyncCoordinator {
        NativeEditorCRDTSyncCoordinator(
            documentEngine: kernel.documentEngine,
            remoteUpdateHandler: { [weak self] update in
                guard let self else { return }
                try await self.commitRemoteUpdate(update)
            },
            localUpdateCommitter: { [weak self] update in
                guard let self else { return false }
                return try await self.commitLocalUpdate(update)
            },
            pendingLocalUpdatesProvider: { [weak self] in
                guard let self else { return [] }
                return try await self.pendingLocalUpdatePayloads()
            },
            localUpdateDidAcknowledge: { [weak self] update in
                guard let self else { return }
                try await self.localPeer.markPushed(update, key: self.key)
            }
        )
    }

    func commitLocalUpdate(_ update: Data, publishProjection: Bool = true) async throws -> Bool {
        let committed = try await localPeer.append(update, origin: .local, key: key)
        guard committed.wasInserted else { return false }
        try await localPeer.clearRetainedDraft(key)
        retainedDraftTitle = nil
        retainedDraft = nil
        if publishProjection, let snapshot = try await kernel.snapshot() {
            publish(snapshot)
        }
        await indexer.documentUpdateCommitted(committed)
        try await compactIfNeeded()
        return true
    }

    func commitRemoteUpdate(_ update: Data) async throws {
        try await kernel.validate(update)
        let committed = try await localPeer.append(update, origin: .remote, key: key)
        guard committed.wasInserted else { return }
        var snapshot = try await kernel.apply(update)
        await indexer.documentUpdateCommitted(committed)
        if retainedDraft != nil {
            snapshot = try await promoteRetainedDraft() ?? snapshot
        }
        if let snapshot {
            publish(snapshot)
        }
        try await compactIfNeeded()
    }

    func pendingLocalUpdatePayloads() async throws -> [Data] {
        try await localPeer.pendingLocalUpdates(key).map(\.payload)
    }

    func compactIfNeeded() async throws {
        guard isCompacting == false else { return }
        let metrics = try await localPeer.metrics(key)
        guard compactionPolicy.shouldCompact(metrics) else { return }

        isCompacting = true
        defer { isCompacting = false }
        let snapshot = try await kernel.encodeState()
        try await kernel.validate(snapshot)
        try await localPeer.compact(key, snapshot: snapshot, through: metrics.lastCommittedSequence)
    }

    func restore(_ state: DocumentStoredState) async throws -> NativeEditorCRDTDocumentSnapshot? {
        var latestSnapshot: NativeEditorCRDTDocumentSnapshot?
        var restoredThroughSequence: Int64 = 0
        if let snapshot = state.snapshot {
            do {
                try await kernel.validate(snapshot)
                latestSnapshot = try await kernel.apply(snapshot)
                restoredThroughSequence = state.snapshotSequence
            } catch {
                if let recoverySnapshot = state.recoverySnapshot {
                    try await kernel.validate(recoverySnapshot)
                    latestSnapshot = try await kernel.apply(recoverySnapshot)
                    restoredThroughSequence = state.recoverySnapshotSequence
                }
            }
        } else if let recoverySnapshot = state.recoverySnapshot {
            try await kernel.validate(recoverySnapshot)
            latestSnapshot = try await kernel.apply(recoverySnapshot)
            restoredThroughSequence = state.recoverySnapshotSequence
        }

        for update in state.updates
            .filter({ $0.sequence > restoredThroughSequence })
            .sorted(by: { $0.sequence < $1.sequence }) {
            try await kernel.validate(update.payload)
            latestSnapshot = try await kernel.apply(update.payload) ?? latestSnapshot
        }
        return latestSnapshot
    }

    func migrateLegacyStateIfNeeded() async throws {
        guard let candidate = try await localPeer.legacyMigrationCandidate(key) else { return }
        let snapshot: Data?
        let pendingLocalUpdate: Data?
        let retainedDraftTitle: String?
        let retainedDraft: ProseMirrorDocument?
        switch candidate.seed {
        case .queuedCRDT(let stateUpdate):
            snapshot = nil
            pendingLocalUpdate = stateUpdate
            retainedDraftTitle = nil
            retainedDraft = nil
        case .queuedProseMirror(let draftTitle, let proseMirrorDocument, let cachedStateUpdate):
            snapshot = cachedStateUpdate
            pendingLocalUpdate = nil
            retainedDraftTitle = draftTitle
            retainedDraft = proseMirrorDocument
        case .cachedCRDT(let stateUpdate):
            snapshot = stateUpdate
            pendingLocalUpdate = nil
            retainedDraftTitle = nil
            retainedDraft = nil
        case .none:
            snapshot = nil
            pendingLocalUpdate = nil
            retainedDraftTitle = nil
            retainedDraft = nil
        }

        _ = try await localPeer.commitLegacyMigration(
            key,
            migration: DocumentLegacyMigrationCommit(
                snapshot: snapshot,
                pendingLocalUpdate: pendingLocalUpdate,
                retainedDraftTitle: retainedDraftTitle,
                retainedDraft: retainedDraft,
                metadataTitle: candidate.metadataTitle,
                metadataBaseTitle: candidate.metadataBaseTitle
            )
        )
    }

    func promoteRetainedDraft() async throws -> NativeEditorCRDTDocumentSnapshot? {
        guard let retainedDraft else { return nil }
        let title = retainedDraftTitle ?? initialSnapshot?.title ?? ""
        let committed = try await kernel.documentEngine.flushPendingLocalChangesForCommit(
            title: title,
            document: NativeEditorDocument(proseMirrorDocument: retainedDraft)
        )
        for update in committed.updates {
            _ = try await commitLocalUpdate(update, publishProjection: false)
        }
        try await localPeer.clearRetainedDraft(key)
        retainedDraftTitle = nil
        self.retainedDraft = nil
        return try await kernel.snapshot()
    }

    func publish(_ snapshot: NativeEditorCRDTDocumentSnapshot) {
        initialSnapshot = snapshot
        for continuation in snapshotContinuations.values {
            continuation.yield(snapshot)
        }
    }
}
