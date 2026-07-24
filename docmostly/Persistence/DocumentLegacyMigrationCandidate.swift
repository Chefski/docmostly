import Foundation

nonisolated enum DocumentLegacyMigrationSeed: Equatable, Sendable {
    case queuedCRDT(stateUpdate: Data)
    case queuedProseMirror(
        title: String,
        document: ProseMirrorDocument,
        cachedStateUpdate: Data?
    )
    case cachedCRDT(stateUpdate: Data)
    case none
}

nonisolated struct DocumentLegacyMigrationCandidate: Equatable, Sendable {
    let seed: DocumentLegacyMigrationSeed
    let metadataTitle: String?
    let metadataBaseTitle: String?
}

nonisolated struct DocumentLegacyMigrationCommit: Equatable, Sendable {
    let snapshot: Data?
    let pendingLocalUpdate: Data?
    let retainedDraftTitle: String?
    let retainedDraft: ProseMirrorDocument?
    let metadataTitle: String?
    let metadataBaseTitle: String?
}
