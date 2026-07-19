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
        _ = remoteBaseDocument
        let acknowledgement = try await acknowledgeCollaborativeDraft(pageId: pageId, through: cutoff)
        guard acknowledgement != .newerPendingUpdatePreserved else {
            return .newerPendingUpdatePreserved
        }
        if title != remoteBaseTitle {
            _ = try await queueOfflineMutation(.updatePageMetadata(
                pageId: pageId,
                title: title,
                baseTitle: remoteBaseTitle
            ))
        }
        _ = try await saveLocalEditableDraft(
            pageId: pageId,
            title: title,
            document: document
        )
        await refreshOfflineMutationCount()
        return .superseded
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
