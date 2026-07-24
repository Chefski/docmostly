import Foundation

nonisolated enum NativeEditorCRDTSyncCoordinatorError: Error, Equatable, Sendable {
    case remotePayloadTooLarge
}

actor NativeEditorCRDTSyncCoordinator {
    nonisolated static let maximumRemoteSyncPayloadBytes = NativeEditorLib0Decoder.maximumDecodedPayloadBytes
    nonisolated static let maximumRemoteSyncSessionBytes = 10_000_000

    private let documentEngine: any NativeEditorCRDTDocumentEngine
    private let remoteUpdateHandler: (@Sendable (Data) async throws -> Void)?
    private let localUpdateCommitter: @Sendable (Data) async throws -> Bool
    private let pendingLocalUpdatesProvider: @Sendable () async throws -> [Data]
    private let localUpdateDidAcknowledge: @Sendable (Data) async throws -> Void
    private var committedLocalUpdateContinuations: [UUID: AsyncStream<Data>.Continuation] = [:]
    private var rawLocalUpdateTask: Task<Void, Never>?
    private var pendingLocalEchoCounts: [Data: Int] = [:]
    private var remoteSyncSessionBytes = 0

    init(
        documentEngine: any NativeEditorCRDTDocumentEngine,
        remoteUpdateHandler: (@Sendable (Data) async throws -> Void)? = nil,
        localUpdateCommitter: @escaping @Sendable (Data) async throws -> Bool = { _ in true },
        pendingLocalUpdatesProvider: @escaping @Sendable () async throws -> [Data] = { [] },
        localUpdateDidAcknowledge: @escaping @Sendable (Data) async throws -> Void = { _ in }
    ) {
        self.documentEngine = documentEngine
        self.remoteUpdateHandler = remoteUpdateHandler
        self.localUpdateCommitter = localUpdateCommitter
        self.pendingLocalUpdatesProvider = pendingLocalUpdatesProvider
        self.localUpdateDidAcknowledge = localUpdateDidAcknowledge
    }

    deinit {
        rawLocalUpdateTask?.cancel()
        for continuation in committedLocalUpdateContinuations.values {
            continuation.finish()
        }
    }

    func makeInitialSyncMessage() async throws -> NativeEditorYjsSyncMessage {
        .stepOne(try await documentEngine.encodeStateVector())
    }

    func receive(_ message: NativeEditorYjsSyncMessage) async throws -> [NativeEditorYjsSyncMessage] {
        switch message {
        case .stepOne(let stateVector):
            try validateRemotePayload(stateVector)
            try recordRemotePayload(stateVector)
            return [.stepTwo(try await documentEngine.encodeStateAsUpdate(for: stateVector))]
        case .stepTwo(let update), .update(let update):
            try validateRemotePayload(update)
            try recordRemotePayload(update)
            guard consumeLocalEcho(for: update) == false else { return [] }
            if let remoteUpdateHandler {
                try await remoteUpdateHandler(update)
            } else {
                try await documentEngine.applyRemoteUpdate(update)
            }
            return []
        }
    }

    func broadcastLocalUpdate(_ update: Data) -> NativeEditorYjsSyncMessage {
        pendingLocalEchoCounts[update, default: 0] += 1
        return .update(update)
    }

    func pendingLocalUpdates() async throws -> [Data] {
        try await pendingLocalUpdatesProvider()
    }

    func recordLocalUpdateAcknowledged(_ update: Data) async throws {
        try await localUpdateDidAcknowledge(update)
    }

    func encodeLocalAwarenessCursor(for selection: NativeEditorLocalTextSelection) async throws
        -> NativeEditorAwarenessCursor? {
        try await documentEngine.encodeLocalAwarenessCursor(for: selection)
    }

    func localUpdates() async -> AsyncStream<Data> {
        localUpdateSubscription().updates
    }

    func localUpdateSubscription() -> (
        updates: AsyncStream<Data>,
        cancel: @Sendable () async -> Void
    ) {
        startRawLocalUpdateForwardingIfNeeded()
        let id = UUID()
        let pair = AsyncStream.makeStream(of: Data.self)
        let cancel: @Sendable () async -> Void = { [weak self] in
            await self?.removeCommittedLocalUpdateContinuation(id)
        }
        committedLocalUpdateContinuations[id] = pair.continuation
        pair.continuation.onTermination = { _ in
            Task { await cancel() }
        }
        return (pair.stream, cancel)
    }

    func integrateLocalChange(_ change: NativeEditorCRDTLocalChange) async throws {
        let updates = try await documentEngine.integrateLocalChangeForCommit(change)
        for update in updates {
            try await commitAndPublishLocalUpdate(update)
        }
    }

    func flushPendingLocalChanges(
        title: String,
        document: NativeEditorDocument
    ) async throws -> NativeEditorCRDTSaveResult {
        let committed = try await documentEngine.flushPendingLocalChangesForCommit(
            title: title,
            document: document
        )
        for update in committed.updates {
            try await commitAndPublishLocalUpdate(update)
        }
        return committed.result
    }

    private func consumeLocalEcho(for update: Data) -> Bool {
        guard let count = pendingLocalEchoCounts[update] else { return false }

        if count == 1 {
            pendingLocalEchoCounts[update] = nil
        } else {
            pendingLocalEchoCounts[update] = count - 1
        }

        return true
    }

    private func commitAndPublishLocalUpdate(_ update: Data) async throws {
        if try await localUpdateCommitter(update) {
            for continuation in committedLocalUpdateContinuations.values {
                continuation.yield(update)
            }
        }
    }

    private func removeCommittedLocalUpdateContinuation(_ id: UUID) {
        committedLocalUpdateContinuations.removeValue(forKey: id)?.finish()
    }

    private func startRawLocalUpdateForwardingIfNeeded() {
        guard rawLocalUpdateTask == nil else { return }
        rawLocalUpdateTask = Task { [weak self, documentEngine] in
            let updates = await documentEngine.localUpdates()
            for await update in updates {
                guard Task.isCancelled == false else { return }
                try? await self?.commitAndPublishLocalUpdate(update)
            }
        }
    }

    private func validateRemotePayload(_ data: Data) throws {
        guard data.count <= Self.maximumRemoteSyncPayloadBytes else {
            throw NativeEditorCRDTSyncCoordinatorError.remotePayloadTooLarge
        }
    }

    private func recordRemotePayload(_ data: Data) throws {
        remoteSyncSessionBytes += data.count
        guard remoteSyncSessionBytes <= Self.maximumRemoteSyncSessionBytes else {
            throw NativeEditorCRDTSyncCoordinatorError.remotePayloadTooLarge
        }
    }
}
