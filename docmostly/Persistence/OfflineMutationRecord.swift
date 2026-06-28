import Foundation

nonisolated struct OfflineMutationRecord: Identifiable, Equatable, Sendable {
    let id: String
    let scope: CacheScope
    let kind: OfflineMutationKind
    let payload: OfflineMutationPayload
    let createdAt: Date
    let updatedAt: Date
    let replayOrder: Int
    let attemptCount: Int
    let lastErrorMessage: String?
}
