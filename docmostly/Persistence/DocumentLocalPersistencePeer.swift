import CryptoKit
import Foundation
import SwiftData

actor DocumentLocalPersistencePeer {
    static let migrationVersion = 1

    private let modelContainer: ModelContainer
    private let compactionFaultInjector: (any DocumentCompactionFaultInjector)?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        modelContainer: ModelContainer,
        compactionFaultInjector: (any DocumentCompactionFaultInjector)? = nil
    ) {
        self.modelContainer = modelContainer
        self.compactionFaultInjector = compactionFaultInjector
    }

    func load(_ key: DocumentStoreKey) throws -> DocumentStoredState {
        let context = ModelContext(modelContainer)
        guard let document = try fetchDocument(key, in: context) else {
            return DocumentStoredState(
                snapshot: nil,
                recoverySnapshot: nil,
                snapshotSequence: 0,
                recoverySnapshotSequence: 0,
                updates: [],
                lastCommittedSequence: 0,
                localClock: 0,
                remoteClock: 0,
                migrationVersion: 0,
                retainedDraftTitle: nil,
                retainedDraft: nil
            )
        }

        let earliestSnapshotSequence = if document.recoverySnapshot == nil {
            document.snapshotSequence
        } else {
            min(document.snapshotSequence, document.recoverySnapshotSequence)
        }
        let updates = try fetchUpdates(key, in: context)
            .filter { $0.sequence > earliestSnapshotSequence && $0.payload != nil }
            .compactMap(Self.storedUpdate)
        return DocumentStoredState(
            snapshot: document.snapshot,
            recoverySnapshot: document.recoverySnapshot,
            snapshotSequence: document.snapshotSequence,
            recoverySnapshotSequence: document.recoverySnapshotSequence,
            updates: updates,
            lastCommittedSequence: max(0, document.nextSequence - 1),
            localClock: document.localClock,
            remoteClock: document.remoteClock,
            migrationVersion: document.migrationVersion,
            retainedDraftTitle: document.retainedDraftTitle,
            retainedDraft: document.retainedDraftData.flatMap { try? decoder.decode(
                ProseMirrorDocument.self,
                from: $0
            ) }
        )
    }

    func retainDraft(
        _ document: ProseMirrorDocument,
        title: String,
        key: DocumentStoreKey
    ) throws {
        let context = ModelContext(modelContainer)
        let storedDocument = try fetchOrInsertDocument(key, in: context)
        storedDocument.retainedDraftTitle = title
        storedDocument.retainedDraftData = try encoder.encode(document)
        storedDocument.retainedDraftUpdatedAt = .now
        storedDocument.updatedAt = .now
        try context.save()
    }

    func clearRetainedDraft(_ key: DocumentStoreKey) throws {
        let context = ModelContext(modelContainer)
        guard let document = try fetchDocument(key, in: context) else { return }
        guard document.retainedDraftData != nil || document.retainedDraftTitle != nil else { return }
        document.retainedDraftTitle = nil
        document.retainedDraftData = nil
        document.retainedDraftUpdatedAt = nil
        document.updatedAt = .now
        try context.save()
    }

    func append(
        _ payload: Data,
        origin: StoredDocumentUpdateOrigin,
        key: DocumentStoreKey
    ) throws -> CommittedDocumentUpdate {
        let digest = Self.digest(payload)
        let context = ModelContext(modelContainer)
        if let existing = try fetchUpdates(key, digest: digest, in: context).first {
            return CommittedDocumentUpdate(
                key: key,
                sequence: existing.sequence,
                clock: existing.clock,
                origin: existing.origin,
                digest: digest,
                payload: payload,
                wasInserted: false
            )
        }

        let document = try fetchOrInsertDocument(key, in: context)
        let sequence = document.nextSequence
        document.nextSequence += 1
        let clock: Int64
        switch origin {
        case .local, .migration:
            document.localClock += 1
            clock = document.localClock
        case .remote:
            document.remoteClock += 1
            clock = document.remoteClock
        }

        let update = StoredDocumentUpdate(
            key: key,
            sequence: sequence,
            clock: clock,
            origin: origin,
            digest: digest,
            payload: payload,
            isPushed: origin == .remote
        )
        context.insert(update)
        document.updatedAt = .now
        if origin == .remote {
            let peer = try fetchOrInsertPeerState(key, in: context)
            peer.advertisedRemoteClock = max(peer.advertisedRemoteClock, clock)
            peer.pulledRemoteClock = max(peer.pulledRemoteClock, clock)
            peer.updatedAt = .now
        }
        try context.save()

        return CommittedDocumentUpdate(
            key: key,
            sequence: sequence,
            clock: clock,
            origin: origin,
            digest: digest,
            payload: payload,
            wasInserted: true
        )
    }

    func pendingLocalUpdates(_ key: DocumentStoreKey) throws -> [DocumentStoredUpdate] {
        try fetchUpdates(key, in: ModelContext(modelContainer))
            .filter { update in
                (update.origin == .local || update.origin == .migration) &&
                    update.isPushed == false &&
                    update.payload != nil
            }
            .compactMap(Self.storedUpdate)
    }

    func markPushed(_ payload: Data, key: DocumentStoreKey) throws {
        let context = ModelContext(modelContainer)
        let digest = Self.digest(payload)
        let matches = try fetchUpdates(key, digest: digest, in: context)
        guard matches.isEmpty == false else { return }
        let safelyCoveredSequence: Int64
        if let document = try fetchDocument(key, in: context),
           document.snapshot != nil,
           document.recoverySnapshot != nil {
            safelyCoveredSequence = min(document.snapshotSequence, document.recoverySnapshotSequence)
        } else {
            safelyCoveredSequence = 0
        }

        let maximumSequence = matches.reduce(Int64(0)) { result, update in
            update.isPushed = true
            if update.sequence <= safelyCoveredSequence {
                update.payload = nil
            }
            return max(result, update.sequence)
        }
        let peer = try fetchOrInsertPeerState(key, in: context)
        peer.pushedLocalSequence = max(peer.pushedLocalSequence, maximumSequence)
        peer.updatedAt = .now
        try context.save()
    }

    func markConnected(_ key: DocumentStoreKey) throws {
        let context = ModelContext(modelContainer)
        let peer = try fetchOrInsertPeerState(key, in: context)
        peer.lastConnectedAt = .now
        peer.updatedAt = .now
        try context.save()
    }

    func metrics(_ key: DocumentStoreKey) throws -> DocumentStoreMetrics {
        let context = ModelContext(modelContainer)
        let document = try fetchDocument(key, in: context)
        let updates = try fetchUpdates(key, in: context).filter { update in
            update.sequence > (document?.snapshotSequence ?? 0) && update.payload != nil
        }
        return DocumentStoreMetrics(
            uncompactedUpdateCount: updates.count,
            uncompactedByteCount: updates.reduce(0) { $0 + ($1.payload?.count ?? 0) },
            lastCommittedSequence: max(0, (document?.nextSequence ?? 1) - 1)
        )
    }

    func compact(_ key: DocumentStoreKey, snapshot: Data, through sequence: Int64) async throws {
        guard snapshot.isEmpty == false else { return }
        let context = ModelContext(modelContainer)
        guard let document = try fetchDocument(key, in: context) else { return }
        guard sequence >= document.snapshotSequence else { return }

        let updates = try fetchUpdates(key, in: context)
        if let previousSnapshot = document.snapshot {
            document.recoverySnapshot = previousSnapshot
            document.recoverySnapshotSequence = document.snapshotSequence
        } else {
            document.recoverySnapshot = snapshot
            document.recoverySnapshotSequence = sequence
        }
        document.snapshot = snapshot
        document.snapshotSequence = sequence
        document.compactedAt = .now
        document.updatedAt = .now
        let safelyCoveredSequence = min(document.snapshotSequence, document.recoverySnapshotSequence)
        for update in updates
        where update.sequence <= safelyCoveredSequence && (update.isPushed || update.origin == .remote) {
            update.payload = nil
        }

        try await compactionFaultInjector?.beforeCompactionCommit()
        try context.save()
    }

    func legacyMigrationCandidate(_ key: DocumentStoreKey) throws -> DocumentLegacyMigrationCandidate? {
        let context = ModelContext(modelContainer)
        if let document = try fetchDocument(key, in: context),
           document.migrationVersion >= Self.migrationVersion {
            return nil
        }

        let queued = try legacyPageMutations(key, in: context)
        let latestPayload = queued.sorted { $0.updatedAt < $1.updatedAt }.last.flatMap { mutation in
            try? decoder.decode(OfflineMutationPayload.self, from: mutation.payloadData)
        }
        let metadata = Self.metadata(from: latestPayload)

        if case .updatePageCRDT(_, _, _, let stateUpdate, _)? = latestPayload {
            return DocumentLegacyMigrationCandidate(
                seed: .queuedCRDT(stateUpdate: stateUpdate),
                metadataTitle: metadata.title,
                metadataBaseTitle: metadata.baseTitle
            )
        }
        if case .updatePage(_, let title, let document, _, _)? = latestPayload {
            let cachedStateUpdate = try fetchLegacyCRDT(key, in: context)?.stateUpdate
            return DocumentLegacyMigrationCandidate(
                seed: .queuedProseMirror(
                    title: title,
                    document: document,
                    cachedStateUpdate: cachedStateUpdate?.isEmpty == false ? cachedStateUpdate : nil
                ),
                metadataTitle: metadata.title,
                metadataBaseTitle: metadata.baseTitle
            )
        }
        if let cached = try fetchLegacyCRDT(key, in: context), cached.stateUpdate.isEmpty == false {
            return DocumentLegacyMigrationCandidate(
                seed: .cachedCRDT(stateUpdate: cached.stateUpdate),
                metadataTitle: metadata.title,
                metadataBaseTitle: metadata.baseTitle
            )
        }
        return DocumentLegacyMigrationCandidate(
            seed: .none,
            metadataTitle: metadata.title,
            metadataBaseTitle: metadata.baseTitle
        )
    }

    @discardableResult
    func commitLegacyMigration(
        _ key: DocumentStoreKey,
        migration: DocumentLegacyMigrationCommit
    ) throws -> Bool {
        let context = ModelContext(modelContainer)
        let document = try fetchOrInsertDocument(key, in: context)
        guard document.migrationVersion < Self.migrationVersion else { return false }

        let existingUpdates = try fetchUpdates(key, in: context)
        let alreadySeeded = document.snapshot != nil || existingUpdates.isEmpty == false
        if alreadySeeded == false {
            if let snapshot = migration.snapshot, snapshot.isEmpty == false {
                document.snapshot = snapshot
                document.recoverySnapshot = snapshot
                document.recoverySnapshotSequence = document.snapshotSequence
            }
            if let pendingLocalUpdate = migration.pendingLocalUpdate, pendingLocalUpdate.isEmpty == false {
                document.localClock += 1
                let update = StoredDocumentUpdate(
                    key: key,
                    sequence: document.nextSequence,
                    clock: document.localClock,
                    origin: .migration,
                    digest: Self.digest(pendingLocalUpdate),
                    payload: pendingLocalUpdate,
                    isPushed: false
                )
                document.nextSequence += 1
                context.insert(update)
            }
            if let retainedDraft = migration.retainedDraft {
                document.retainedDraftTitle = migration.retainedDraftTitle
                document.retainedDraftData = try encoder.encode(retainedDraft)
                document.retainedDraftUpdatedAt = .now
            }
        }

        try replaceLegacyBodyMutations(
            key,
            title: migration.metadataTitle,
            baseTitle: migration.metadataBaseTitle,
            in: context
        )
        if let cached = try fetchLegacyCRDT(key, in: context) {
            context.delete(cached)
        }
        document.migrationVersion = Self.migrationVersion
        document.updatedAt = .now
        try context.save()
        return true
    }
}

private extension DocumentLocalPersistencePeer {
    struct LegacyMetadata {
        let title: String?
        let baseTitle: String?
    }

    static func storedUpdate(_ update: StoredDocumentUpdate) -> DocumentStoredUpdate? {
        guard let payload = update.payload else { return nil }
        return DocumentStoredUpdate(
            sequence: update.sequence,
            clock: update.clock,
            origin: update.origin,
            digest: update.digest,
            payload: payload,
            isPushed: update.isPushed
        )
    }

    static func digest(_ data: Data) -> String {
        let digits = Array("0123456789abcdef".utf8)
        let bytes = SHA256.hash(data: data).flatMap { byte in
            [digits[Int(byte >> 4)], digits[Int(byte & 0x0f)]]
        }
        return String(bytes: bytes, encoding: .utf8) ?? ""
    }

    static func metadata(from payload: OfflineMutationPayload?) -> LegacyMetadata {
        guard let payload else {
            return LegacyMetadata(title: nil, baseTitle: nil)
        }
        switch payload {
        case .updatePage(_, let title, _, let baseTitle, _),
                .updatePageCRDT(_, let title, _, _, let baseTitle),
                .updatePageMetadata(_, let title, let baseTitle):
            return LegacyMetadata(title: title, baseTitle: baseTitle)
        default:
            return LegacyMetadata(title: nil, baseTitle: nil)
        }
    }

    func fetchDocument(_ key: DocumentStoreKey, in context: ModelContext) throws -> StoredDocument? {
        let schemaVersion = key.schemaVersion
        let serverBaseURL = key.serverBaseURL
        let userID = key.userID
        let workspaceID = key.workspaceID
        let pageID = key.pageID
        var descriptor = FetchDescriptor<StoredDocument>(predicate: #Predicate { document in
            document.schemaVersion == schemaVersion &&
                document.serverBaseURL == serverBaseURL &&
                document.userID == userID &&
                document.workspaceID == workspaceID &&
                document.pageID == pageID
        })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func fetchOrInsertDocument(_ key: DocumentStoreKey, in context: ModelContext) throws -> StoredDocument {
        if let document = try fetchDocument(key, in: context) {
            return document
        }
        let document = StoredDocument(key: key)
        context.insert(document)
        return document
    }

    func fetchUpdates(
        _ key: DocumentStoreKey,
        digest: String? = nil,
        in context: ModelContext
    ) throws -> [StoredDocumentUpdate] {
        let schemaVersion = key.schemaVersion
        let serverBaseURL = key.serverBaseURL
        let userID = key.userID
        let workspaceID = key.workspaceID
        let pageID = key.pageID
        let descriptor: FetchDescriptor<StoredDocumentUpdate>
        if let digest {
            descriptor = FetchDescriptor(
                predicate: #Predicate { update in
                    update.schemaVersion == schemaVersion &&
                        update.serverBaseURL == serverBaseURL &&
                        update.userID == userID &&
                        update.workspaceID == workspaceID &&
                        update.pageID == pageID &&
                        update.digest == digest
                },
                sortBy: [SortDescriptor(\.sequence)]
            )
        } else {
            descriptor = FetchDescriptor(
                predicate: #Predicate { update in
                    update.schemaVersion == schemaVersion &&
                        update.serverBaseURL == serverBaseURL &&
                        update.userID == userID &&
                        update.workspaceID == workspaceID &&
                        update.pageID == pageID
                },
                sortBy: [SortDescriptor(\.sequence)]
            )
        }
        return try context.fetch(descriptor)
    }

    func fetchOrInsertPeerState(
        _ key: DocumentStoreKey,
        in context: ModelContext
    ) throws -> StoredDocumentPeerState {
        let schemaVersion = key.schemaVersion
        let serverBaseURL = key.serverBaseURL
        let userID = key.userID
        let workspaceID = key.workspaceID
        let pageID = key.pageID
        let peerID = "collaboration"
        var descriptor = FetchDescriptor<StoredDocumentPeerState>(predicate: #Predicate { peer in
            peer.schemaVersion == schemaVersion &&
                peer.serverBaseURL == serverBaseURL &&
                peer.userID == userID &&
                peer.workspaceID == workspaceID &&
                peer.pageID == pageID &&
                peer.peerID == peerID
        })
        descriptor.fetchLimit = 1
        if let peer = try context.fetch(descriptor).first {
            return peer
        }
        let peer = StoredDocumentPeerState(key: key, peerID: peerID)
        context.insert(peer)
        return peer
    }

    func fetchLegacyCRDT(_ key: DocumentStoreKey, in context: ModelContext) throws -> CachedCRDTDocument? {
        let serverBaseURL = key.serverBaseURL
        let userID = key.userID
        let pageID = key.pageID
        var descriptor = FetchDescriptor<CachedCRDTDocument>(predicate: #Predicate { document in
            document.cacheServerBaseURL == serverBaseURL &&
                document.cacheUserID == userID &&
                document.pageId == pageID
        })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func legacyPageMutations(
        _ key: DocumentStoreKey,
        in context: ModelContext
    ) throws -> [QueuedOfflineMutation] {
        let serverBaseURL = key.serverBaseURL
        let userID = key.userID
        let kind = OfflineMutationKind.updatePage.rawValue
        let mutations = try context.fetch(FetchDescriptor<QueuedOfflineMutation>(
            predicate: #Predicate { mutation in
                mutation.cacheServerBaseURL == serverBaseURL &&
                    mutation.cacheUserID == userID &&
                    mutation.kindRaw == kind
            }
        ))
        return mutations.filter { mutation in
            guard let payload = try? decoder.decode(OfflineMutationPayload.self, from: mutation.payloadData) else {
                return false
            }
            switch payload {
            case .updatePage(let pageID, _, _, _, _),
                    .updatePageCRDT(let pageID, _, _, _, _),
                    .updatePageMetadata(let pageID, _, _):
                return pageID == key.pageID
            default:
                return false
            }
        }
    }

    func replaceLegacyBodyMutations(
        _ key: DocumentStoreKey,
        title: String?,
        baseTitle: String?,
        in context: ModelContext
    ) throws {
        let mutations = try legacyPageMutations(key, in: context)
        let bodyMutations = mutations.filter { mutation in
            guard let payload = try? decoder.decode(OfflineMutationPayload.self, from: mutation.payloadData) else {
                return false
            }
            switch payload {
            case .updatePage, .updatePageCRDT:
                return true
            default:
                return false
            }
        }
        guard bodyMutations.isEmpty == false else { return }

        let retained = bodyMutations.min { $0.replayOrder < $1.replayOrder }
        if let retained, let title {
            let payload = OfflineMutationPayload.updatePageMetadata(
                pageId: key.pageID,
                title: title,
                baseTitle: baseTitle
            )
            retained.kindRaw = payload.kind.rawValue
            retained.coalescingKey = payload.coalescingKey
            retained.payloadData = try encoder.encode(payload)
            retained.updatedAt = .now
        } else if let retained {
            context.delete(retained)
        }

        for mutation in bodyMutations where mutation.id != retained?.id {
            context.delete(mutation)
        }
    }
}
