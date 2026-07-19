import Foundation
import SwiftData

nonisolated enum OfflinePageUpdateSupersessionResult: Equatable, Sendable {
    case enqueued
    case superseded
    case newerPendingUpdatePreserved
}

nonisolated enum OfflinePageUpdateAcknowledgementResult: Equatable, Sendable {
    case noPendingUpdate
    case acknowledged
    case newerPendingUpdatePreserved
}

nonisolated final class OfflineMutationQueue {
    private let context: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func enqueue(_ payload: OfflineMutationPayload, scope: CacheScope) throws -> OfflineMutationRecord {
        let payload = try preservingOldestPageUpdateBase(in: payload, scope: scope)
        let payloadData = try encoder.encode(payload)
        let replacementOrder = try removeCoalescedMutation(for: payload, scope: scope)
        let replayOrder = if let replacementOrder {
            replacementOrder
        } else {
            try nextReplayOrder(scope: scope)
        }
        let mutation = QueuedOfflineMutation(
            payload: payload,
            scope: scope,
            payloadData: payloadData,
            replayOrder: replayOrder
        )
        context.insert(mutation)
        try context.save()
        return try record(from: mutation)
    }

    func supersedePendingPageUpdate(
        pageId: String,
        title: String,
        document: ProseMirrorDocument,
        baseTitle: String? = nil,
        baseDocument: ProseMirrorDocument? = nil,
        snapshotCapturedAt: Date,
        scope: CacheScope
    ) throws -> OfflinePageUpdateSupersessionResult {
        var payload = OfflineMutationPayload.updatePage(
            pageId: pageId,
            title: title,
            document: document,
            baseTitle: baseTitle,
            baseDocument: baseDocument
        )
        let coalescingKey = "\(OfflineMutationKind.updatePage.rawValue):\(pageId)"
        let matches = try pageUpdateMutations(coalescingKey: coalescingKey, scope: scope)
        guard let retainedMutation = matches.first else {
            let mutation = QueuedOfflineMutation(
                payload: payload,
                scope: scope,
                payloadData: try encoder.encode(payload),
                replayOrder: try nextReplayOrder(scope: scope)
            )
            mutation.createdAt = snapshotCapturedAt
            mutation.updatedAt = snapshotCapturedAt
            context.insert(mutation)
            try context.save()
            return .enqueued
        }
        let retainedPayload = try decoder.decode(OfflineMutationPayload.self, from: retainedMutation.payloadData)
        let oldestBaseDocument = if case .updatePage(_, _, _, _, let document) = retainedPayload {
            document
        } else {
            baseDocument
        }
        payload = .updatePage(
            pageId: pageId,
            title: title,
            document: document,
            baseTitle: retainedPayload.pageUpdateBaseTitle ?? baseTitle,
            baseDocument: oldestBaseDocument
        )
        guard matches.allSatisfy({ $0.createdAt <= snapshotCapturedAt }) else {
            return .newerPendingUpdatePreserved
        }

        retainedMutation.kindRaw = payload.kind.rawValue
        retainedMutation.coalescingKey = coalescingKey
        retainedMutation.payloadData = try encoder.encode(payload)
        retainedMutation.createdAt = snapshotCapturedAt
        retainedMutation.updatedAt = .now
        retainedMutation.attemptCount = 0
        retainedMutation.lastErrorMessage = nil

        for mutation in matches.dropFirst() {
            context.delete(mutation)
        }
        try context.save()
        return .superseded
    }

    func acknowledgePendingPageUpdate(
        pageId: String,
        snapshotCapturedAt: Date,
        scope: CacheScope
    ) throws -> OfflinePageUpdateAcknowledgementResult {
        let coalescingKey = "\(OfflineMutationKind.updatePage.rawValue):\(pageId)"
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
        guard matches.isEmpty == false else { return .noPendingUpdate }
        guard matches.allSatisfy({ $0.createdAt <= snapshotCapturedAt }) else {
            return .newerPendingUpdatePreserved
        }

        for mutation in matches {
            context.delete(mutation)
        }
        try context.save()
        return .acknowledged
    }

    // swiftlint:disable:next function_parameter_count
    func resolvePendingPageUpdateKeepingLocal(
        pageId: String,
        title: String,
        document: ProseMirrorDocument,
        remoteBaseTitle: String,
        remoteBaseDocument: ProseMirrorDocument,
        replacingThrough cutoff: Date,
        resolvedAt: Date,
        scope: CacheScope
    ) throws -> OfflinePageUpdateSupersessionResult {
        let legacyPayload = OfflineMutationPayload.updatePage(
            pageId: pageId,
            title: title,
            document: document,
            baseTitle: remoteBaseTitle,
            baseDocument: remoteBaseDocument
        )
        let coalescingKey = "\(OfflineMutationKind.updatePage.rawValue):\(pageId)"
        let serverBaseURL = scope.serverBaseURL
        let userID = scope.userID
        let descriptor = FetchDescriptor<QueuedOfflineMutation>(
            predicate: #Predicate { mutation in
                mutation.cacheServerBaseURL == serverBaseURL &&
                    mutation.cacheUserID == userID &&
                    mutation.coalescingKey == coalescingKey
            },
            sortBy: [
                SortDescriptor(\.replayOrder),
                SortDescriptor(\.createdAt)
            ]
        )
        let matches = try context.fetch(descriptor)

        guard matches.allSatisfy({ $0.createdAt <= cutoff }) else {
            return .newerPendingUpdatePreserved
        }

        guard let retainedMutation = matches.first else {
            let mutation = QueuedOfflineMutation(
                payload: legacyPayload,
                scope: scope,
                payloadData: try encoder.encode(legacyPayload),
                replayOrder: try nextReplayOrder(scope: scope),
                createdAt: resolvedAt
            )
            context.insert(mutation)
            try context.save()
            return .enqueued
        }

        let payload = try resolvedPageUpdatePayload(
            from: retainedMutation,
            legacyPayload: legacyPayload,
            title: title,
            document: document,
            remoteBaseTitle: remoteBaseTitle
        )

        retainedMutation.kindRaw = payload.kind.rawValue
        retainedMutation.coalescingKey = coalescingKey
        retainedMutation.payloadData = try encoder.encode(payload)
        retainedMutation.createdAt = resolvedAt
        retainedMutation.updatedAt = resolvedAt
        retainedMutation.attemptCount = 0
        retainedMutation.lastErrorMessage = nil

        for mutation in matches.dropFirst() {
            context.delete(mutation)
        }
        try context.save()
        return .superseded
    }

    func removePendingPageLabel(pageId: String, localId: String, scope: CacheScope) throws {
        try updatePendingMutations(scope: scope) { payload in
            guard case .addPageLabels(let queuedPageId, let labels) = payload, queuedPageId == pageId else {
                return .unchanged
            }

            let filteredLabels = labels.filter { $0.id != localId }
            guard filteredLabels.count != labels.count else {
                return .unchanged
            }
            guard filteredLabels.isEmpty == false else {
                return .delete
            }
            return .replace(.addPageLabels(pageId: pageId, labels: filteredLabels))
        }
    }

    func replaceQueuedInlineCommentID(localId: String, serverId: String, scope: CacheScope) throws {
        try updatePendingMutations(scope: scope) { payload in
            let replacement = payload.replacingCommentIDs([localId: serverId])
            return replacement == payload ? .unchanged : .replace(replacement)
        }
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

    private func preservingOldestPageUpdateBase(
        in payload: OfflineMutationPayload,
        scope: CacheScope
    ) throws -> OfflineMutationPayload {
        guard payload.kind == .updatePage, let coalescingKey = payload.coalescingKey else { return payload }

        let serverBaseURL = scope.serverBaseURL
        let userID = scope.userID
        var descriptor = FetchDescriptor<QueuedOfflineMutation>(
            predicate: #Predicate { mutation in
                mutation.cacheServerBaseURL == serverBaseURL &&
                    mutation.cacheUserID == userID &&
                    mutation.coalescingKey == coalescingKey
            },
            sortBy: [SortDescriptor(\.createdAt)]
        )
        descriptor.fetchLimit = 1
        guard let existingMutation = try context.fetch(descriptor).first else { return payload }
        let existingPayload = try decoder.decode(OfflineMutationPayload.self, from: existingMutation.payloadData)

        switch payload {
        case .updatePage(let pageId, let title, let document, _, let baseDocument):
            let oldestBaseDocument = if case .updatePage(_, _, _, _, let document) = existingPayload {
                document
            } else {
                baseDocument
            }
            return .updatePage(
                pageId: pageId,
                title: title,
                document: document,
                baseTitle: existingPayload.pageUpdateBaseTitle,
                baseDocument: oldestBaseDocument
            )
        case .updatePageCRDT(let pageId, let title, let document, let stateUpdate, _):
            return .updatePageCRDT(
                pageId: pageId,
                title: title,
                document: document,
                stateUpdate: stateUpdate,
                baseTitle: existingPayload.pageUpdateBaseTitle
            )
        default:
            return payload
        }
    }

    private enum PendingMutationUpdate {
        case unchanged
        case replace(OfflineMutationPayload)
        case delete
    }

    private enum PreparedPendingMutationUpdate {
        case replace(payloadData: Data, kindRaw: String, coalescingKey: String?)
        case delete
    }

    private func updatePendingMutations(
        scope: CacheScope,
        transform: (OfflineMutationPayload) throws -> PendingMutationUpdate
    ) throws {
        let serverBaseURL = scope.serverBaseURL
        let userID = scope.userID
        let descriptor = FetchDescriptor<QueuedOfflineMutation>(
            predicate: #Predicate { mutation in
                mutation.cacheServerBaseURL == serverBaseURL && mutation.cacheUserID == userID
            }
        )
        let mutations = try context.fetch(descriptor)
        var changes: [(mutation: QueuedOfflineMutation, update: PreparedPendingMutationUpdate)] = []

        for mutation in mutations {
            let payload = try decoder.decode(OfflineMutationPayload.self, from: mutation.payloadData)
            switch try transform(payload) {
            case .unchanged:
                continue
            case .replace(let replacement):
                let payloadData = try encoder.encode(replacement)
                changes.append((
                    mutation,
                    .replace(
                        payloadData: payloadData,
                        kindRaw: replacement.kind.rawValue,
                        coalescingKey: replacement.coalescingKey
                    )
                ))
            case .delete:
                changes.append((mutation, .delete))
            }
        }

        guard changes.isEmpty == false else { return }
        for change in changes {
            switch change.update {
            case .replace(let payloadData, let kindRaw, let coalescingKey):
                change.mutation.kindRaw = kindRaw
                change.mutation.coalescingKey = coalescingKey
                change.mutation.payloadData = payloadData
                change.mutation.updatedAt = Date.now
            case .delete:
                context.delete(change.mutation)
            }
        }
        try context.save()
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

nonisolated extension OfflineMutationQueue {
    func removeCoalescedMutations(for payload: OfflineMutationPayload, scope: CacheScope) throws {
        _ = try removeCoalescedMutation(for: payload, scope: scope)
        try context.save()
    }

    // swiftlint:disable:next function_parameter_count
    func supersedePendingCRDTPageUpdate(
        pageId: String,
        title: String,
        document: ProseMirrorDocument,
        stateUpdate: Data,
        baseTitle: String? = nil,
        snapshotCapturedAt: Date,
        scope: CacheScope
    ) throws -> OfflinePageUpdateSupersessionResult {
        var payload = OfflineMutationPayload.updatePageCRDT(
            pageId: pageId,
            title: title,
            document: document,
            stateUpdate: stateUpdate,
            baseTitle: baseTitle
        )
        let coalescingKey = "\(OfflineMutationKind.updatePage.rawValue):\(pageId)"
        let matches = try pageUpdateMutations(coalescingKey: coalescingKey, scope: scope)

        guard let retainedMutation = matches.first else {
            let mutation = QueuedOfflineMutation(
                payload: payload,
                scope: scope,
                payloadData: try encoder.encode(payload),
                replayOrder: try nextReplayOrder(scope: scope),
                createdAt: snapshotCapturedAt
            )
            context.insert(mutation)
            try context.save()
            return .enqueued
        }

        let retainedPayload = try decoder.decode(OfflineMutationPayload.self, from: retainedMutation.payloadData)
        payload = .updatePageCRDT(
            pageId: pageId,
            title: title,
            document: document,
            stateUpdate: stateUpdate,
            baseTitle: retainedPayload.pageUpdateBaseTitle ?? baseTitle
        )
        guard matches.allSatisfy({ $0.createdAt <= snapshotCapturedAt }) else {
            return .newerPendingUpdatePreserved
        }

        retainedMutation.kindRaw = payload.kind.rawValue
        retainedMutation.coalescingKey = coalescingKey
        retainedMutation.payloadData = try encoder.encode(payload)
        retainedMutation.createdAt = snapshotCapturedAt
        retainedMutation.updatedAt = .now
        retainedMutation.attemptCount = 0
        retainedMutation.lastErrorMessage = nil

        for mutation in matches.dropFirst() {
            context.delete(mutation)
        }
        try context.save()
        return .superseded
    }

    private func pageUpdateMutations(
        coalescingKey: String,
        scope: CacheScope
    ) throws -> [QueuedOfflineMutation] {
        let serverBaseURL = scope.serverBaseURL
        let userID = scope.userID
        let descriptor = FetchDescriptor<QueuedOfflineMutation>(
            predicate: #Predicate { mutation in
                mutation.cacheServerBaseURL == serverBaseURL &&
                    mutation.cacheUserID == userID &&
                    mutation.coalescingKey == coalescingKey
            },
            sortBy: [
                SortDescriptor(\.replayOrder),
                SortDescriptor(\.createdAt)
            ]
        )
        return try context.fetch(descriptor)
    }

    private func resolvedPageUpdatePayload(
        from retainedMutation: QueuedOfflineMutation,
        legacyPayload: OfflineMutationPayload,
        title: String,
        document: ProseMirrorDocument,
        remoteBaseTitle: String
    ) throws -> OfflineMutationPayload {
        let retainedPayload = try decoder.decode(
            OfflineMutationPayload.self,
            from: retainedMutation.payloadData
        )
        guard case .updatePageCRDT(let pageId, _, _, let stateUpdate, _) = retainedPayload else {
            return legacyPayload
        }
        return .updatePageCRDT(
            pageId: pageId,
            title: title,
            document: document,
            stateUpdate: stateUpdate,
            baseTitle: remoteBaseTitle
        )
    }
}

nonisolated private extension OfflineMutationPayload {
    var pageUpdateBaseTitle: String? {
        switch self {
        case .updatePage(_, _, _, let baseTitle, _),
                .updatePageCRDT(_, _, _, _, let baseTitle):
            baseTitle
        default:
            nil
        }
    }
}
