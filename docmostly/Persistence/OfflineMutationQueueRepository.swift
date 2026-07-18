import Foundation
import SwiftData

actor OfflineMutationQueueRepository {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    @discardableResult
    func enqueue(_ payload: OfflineMutationPayload, scope: CacheScope) throws -> OfflineMutationRecord {
        try queue().enqueue(payload, scope: scope)
    }

    func pending(scope: CacheScope, limit: Int? = nil) throws -> [OfflineMutationRecord] {
        try queue().pending(scope: scope, limit: limit)
    }

    func count(scope: CacheScope) throws -> Int {
        try queue().count(scope: scope)
    }

    func remove(id: String, scope: CacheScope) throws {
        try queue().remove(id: id, scope: scope)
    }

    func removeCoalescedMutations(for payload: OfflineMutationPayload, scope: CacheScope) throws {
        try queue().removeCoalescedMutations(for: payload, scope: scope)
    }

    func supersedePendingPageUpdate(
        pageId: String,
        title: String,
        document: ProseMirrorDocument,
        baseDocument: ProseMirrorDocument? = nil,
        snapshotCapturedAt: Date,
        scope: CacheScope
    ) throws -> OfflinePageUpdateSupersessionResult {
        try queue().supersedePendingPageUpdate(
            pageId: pageId,
            title: title,
            document: document,
            baseDocument: baseDocument,
            snapshotCapturedAt: snapshotCapturedAt,
            scope: scope
        )
    }

    func acknowledgePendingPageUpdate(
        pageId: String,
        snapshotCapturedAt: Date,
        scope: CacheScope
    ) throws -> OfflinePageUpdateAcknowledgementResult {
        try queue().acknowledgePendingPageUpdate(
            pageId: pageId,
            snapshotCapturedAt: snapshotCapturedAt,
            scope: scope
        )
    }

    // swiftlint:disable:next function_parameter_count
    func resolvePendingPageUpdateKeepingLocal(
        pageId: String,
        title: String,
        document: ProseMirrorDocument,
        remoteBaseDocument: ProseMirrorDocument,
        replacingThrough cutoff: Date,
        resolvedAt: Date,
        scope: CacheScope
    ) throws -> OfflinePageUpdateSupersessionResult {
        try queue().resolvePendingPageUpdateKeepingLocal(
            pageId: pageId,
            title: title,
            document: document,
            remoteBaseDocument: remoteBaseDocument,
            replacingThrough: cutoff,
            resolvedAt: resolvedAt,
            scope: scope
        )
    }

    func removePendingPageLabel(pageId: String, localId: String, scope: CacheScope) throws {
        try queue().removePendingPageLabel(pageId: pageId, localId: localId, scope: scope)
    }

    func replaceQueuedInlineCommentID(localId: String, serverId: String, scope: CacheScope) throws {
        try queue().replaceQueuedInlineCommentID(localId: localId, serverId: serverId, scope: scope)
    }

    func markFailed(id: String, scope: CacheScope, message: String) throws {
        try queue().markFailed(id: id, scope: scope, message: message)
    }

    private func queue() -> OfflineMutationQueue {
        OfflineMutationQueue(context: ModelContext(modelContainer))
    }
}
