import Foundation

nonisolated struct DocumentStoredUpdate: Equatable, Sendable {
    let sequence: Int64
    let clock: Int64
    let origin: StoredDocumentUpdateOrigin
    let digest: String
    let payload: Data
    let isPushed: Bool
}

nonisolated struct DocumentStoredState: Equatable, Sendable {
    let snapshot: Data?
    let recoverySnapshot: Data?
    let snapshotSequence: Int64
    let updates: [DocumentStoredUpdate]
    let lastCommittedSequence: Int64
    let localClock: Int64
    let remoteClock: Int64
    let migrationVersion: Int
    let retainedDraftTitle: String?
    let retainedDraft: ProseMirrorDocument?

    var hasLocalState: Bool {
        snapshot != nil || recoverySnapshot != nil || updates.isEmpty == false
    }
}

nonisolated struct CommittedDocumentUpdate: Equatable, Sendable {
    let key: DocumentStoreKey
    let sequence: Int64
    let clock: Int64
    let origin: StoredDocumentUpdateOrigin
    let digest: String
    let payload: Data
    let wasInserted: Bool
}

nonisolated struct DocumentStoreMetrics: Equatable, Sendable {
    let uncompactedUpdateCount: Int
    let uncompactedByteCount: Int
    let lastCommittedSequence: Int64
}
