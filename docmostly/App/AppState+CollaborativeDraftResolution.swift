import Foundation

extension AppState {
    func pauseOfflineReplayForCollaborativeResolution() async {
        let replayTask = offlineReplayTask
        replayTask?.cancel()
        await replayTask?.value
        offlineReplayTask = nil
    }

    func discardPendingCollaborativeDraft(
        pageId: String,
        through cutoff: Date
    ) async throws -> OfflinePageUpdateAcknowledgementResult {
        await pauseOfflineReplayForCollaborativeResolution()

        do {
            let result = try await acknowledgeCollaborativeDraft(
                pageId: pageId,
                through: cutoff
            )
            await refreshOfflineMutationCount()
            scheduleOfflineQueueReconciliation()
            return result
        } catch {
            await refreshOfflineMutationCount()
            scheduleOfflineQueueReconciliation()
            throw error
        }
    }

    // swiftlint:disable:next function_parameter_count
    func keepPendingCollaborativeDraft(
        pageId: String,
        title: String,
        document: ProseMirrorDocument,
        remoteBaseTitle: String,
        remoteBaseDocument: ProseMirrorDocument,
        replacingThrough cutoff: Date
    ) async throws -> OfflinePageUpdateSupersessionResult {
        await pauseOfflineReplayForCollaborativeResolution()
        let scope = try requireCacheScope(
            message: "The local draft cannot be secured until you sign in again."
        )
        let resolvedAt = Date.now
        let result: OfflinePageUpdateSupersessionResult

        if let offlineQueueRepository {
            result = try await offlineQueueRepository.resolvePendingPageUpdateKeepingLocal(
                pageId: pageId,
                title: title,
                document: document,
                remoteBaseTitle: remoteBaseTitle,
                remoteBaseDocument: remoteBaseDocument,
                replacingThrough: cutoff,
                resolvedAt: resolvedAt,
                scope: scope
            )
        } else if let offlineQueue {
            result = try offlineQueue.resolvePendingPageUpdateKeepingLocal(
                pageId: pageId,
                title: title,
                document: document,
                remoteBaseTitle: remoteBaseTitle,
                remoteBaseDocument: remoteBaseDocument,
                replacingThrough: cutoff,
                resolvedAt: resolvedAt,
                scope: scope
            )
        } else {
            throw APIError.connectionFailed("Local draft storage is unavailable on this device.")
        }

        guard result != .newerPendingUpdatePreserved else { return result }
        _ = try await saveLocalEditableDraft(
            pageId: pageId,
            title: title,
            document: document
        )
        await refreshOfflineMutationCount()
        return result
    }

    private func acknowledgeCollaborativeDraft(
        pageId: String,
        through cutoff: Date
    ) async throws -> OfflinePageUpdateAcknowledgementResult {
        guard let cacheScope else { return .noPendingUpdate }

        if let offlineQueueRepository {
            return try await offlineQueueRepository.acknowledgePendingPageUpdate(
                pageId: pageId,
                snapshotCapturedAt: cutoff,
                scope: cacheScope
            )
        }

        guard let offlineQueue else { return .noPendingUpdate }
        return try offlineQueue.acknowledgePendingPageUpdate(
            pageId: pageId,
            snapshotCapturedAt: cutoff,
            scope: cacheScope
        )
    }
}
