import Foundation
import SwiftData

nonisolated final class OfflineMutationQueue {
    private let context: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func enqueue(_ payload: OfflineMutationPayload, scope: CacheScope) throws -> OfflineMutationRecord {
        let replacementOrder = try removeCoalescedMutation(for: payload, scope: scope)
        let payloadData = try encoder.encode(payload)
        let mutation = QueuedOfflineMutation(
            payload: payload,
            scope: scope,
            payloadData: payloadData,
            replayOrder: replacementOrder ?? nextReplayOrder(scope: scope)
        )
        context.insert(mutation)
        try context.save()
        return try record(from: mutation)
    }

    func pending(scope: CacheScope, limit: Int? = nil) throws -> [OfflineMutationRecord] {
        let serverBaseURL = scope.serverBaseURL
        let userID = scope.userID
        var descriptor = FetchDescriptor<QueuedOfflineMutation>(
            predicate: #Predicate { mutation in
                mutation.cacheServerBaseURL == serverBaseURL && mutation.cacheUserID == userID
            },
            sortBy: [
                SortDescriptor(\.replayOrder),
                SortDescriptor(\.createdAt)
            ]
        )
        if let limit {
            descriptor.fetchLimit = limit
        }
        return try context.fetch(descriptor).map(record(from:))
    }

    func count(scope: CacheScope) throws -> Int {
        let serverBaseURL = scope.serverBaseURL
        let userID = scope.userID
        let descriptor = FetchDescriptor<QueuedOfflineMutation>(
            predicate: #Predicate { mutation in
                mutation.cacheServerBaseURL == serverBaseURL && mutation.cacheUserID == userID
            }
        )
        return try context.fetchCount(descriptor)
    }

    func remove(id: String, scope: CacheScope) throws {
        guard let mutation = try mutation(id: id, scope: scope) else { return }
        context.delete(mutation)
        try context.save()
    }

    func markFailed(id: String, scope: CacheScope, message: String) throws {
        guard let mutation = try mutation(id: id, scope: scope) else { return }
        mutation.attemptCount += 1
        mutation.lastErrorMessage = message
        mutation.updatedAt = Date.now
        try context.save()
    }

    private func removeCoalescedMutation(for payload: OfflineMutationPayload, scope: CacheScope) throws -> Int? {
        guard let coalescingKey = payload.coalescingKey else { return nil }

        let serverBaseURL = scope.serverBaseURL
        let userID = scope.userID
        let descriptor = FetchDescriptor<QueuedOfflineMutation>(
            predicate: #Predicate { mutation in
                mutation.cacheServerBaseURL == serverBaseURL &&
                    mutation.cacheUserID == userID &&
                    mutation.coalescingKey == coalescingKey
            }
        )
        let matches = try context.fetch(descriptor)
        let replayOrder = matches.map(\.replayOrder).min()
        for mutation in matches {
            context.delete(mutation)
        }
        return replayOrder
    }

    private func nextReplayOrder(scope: CacheScope) throws -> Int {
        let serverBaseURL = scope.serverBaseURL
        let userID = scope.userID
        var descriptor = FetchDescriptor<QueuedOfflineMutation>(
            predicate: #Predicate { mutation in
                mutation.cacheServerBaseURL == serverBaseURL && mutation.cacheUserID == userID
            },
            sortBy: [SortDescriptor(\.replayOrder, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return (try context.fetch(descriptor).first?.replayOrder ?? -1) + 1
    }

    private func mutation(id: String, scope: CacheScope) throws -> QueuedOfflineMutation? {
        let mutationID = id
        let serverBaseURL = scope.serverBaseURL
        let userID = scope.userID
        var descriptor = FetchDescriptor<QueuedOfflineMutation>(
            predicate: #Predicate { mutation in
                mutation.id == mutationID &&
                    mutation.cacheServerBaseURL == serverBaseURL &&
                    mutation.cacheUserID == userID
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func record(from mutation: QueuedOfflineMutation) throws -> OfflineMutationRecord {
        guard let kind = OfflineMutationKind(rawValue: mutation.kindRaw) else {
            throw APIError.connectionFailed("Queued offline change has an unknown operation type.")
        }

        return OfflineMutationRecord(
            id: mutation.id,
            scope: CacheScope(serverBaseURL: mutation.cacheServerBaseURL, userID: mutation.cacheUserID),
            kind: kind,
            payload: try decoder.decode(OfflineMutationPayload.self, from: mutation.payloadData),
            createdAt: mutation.createdAt,
            updatedAt: mutation.updatedAt,
            replayOrder: mutation.replayOrder,
            attemptCount: mutation.attemptCount,
            lastErrorMessage: mutation.lastErrorMessage
        )
    }
}
