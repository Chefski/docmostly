import Foundation

nonisolated struct CollaborativePagePersistenceResult: Sendable {
    let page: DocmostEditablePage?
    let persistedTitle: String
    let updatedAt: Date?
}

extension AppState {
    func updatePage(
        pageId: String,
        title: String,
        document: ProseMirrorDocument,
        baseTitle: String? = nil,
        baseDocument: ProseMirrorDocument? = nil
    ) async throws -> DocmostEditablePage {
        guard let apiClient else {
            return try await queuePageUpdate(
                pageId: pageId,
                title: title,
                document: document,
                baseTitle: baseTitle,
                baseDocument: baseDocument
            )
        }

        do {
            let page: DocmostEditablePage = try await apiClient.send(.updatePage(
                pageId: pageId,
                title: title,
                content: document,
                format: .json,
                operation: .replace
            ))
            isOffline = false
            if let cacheScope {
                scheduleCacheWrite(.saveEditablePage(page, scope: cacheScope))
            }
            do {
                try await clearPendingPageUpdate(pageId: pageId, title: title, document: document)
                scheduleOfflineQueueReconciliation()
            } catch {
                statusMessage = error.localizedDescription
            }
            return page
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            return try await queuePageUpdate(
                pageId: pageId,
                title: title,
                document: document,
                baseTitle: baseTitle,
                baseDocument: baseDocument
            )
        }
    }

    // swiftlint:disable:next function_parameter_count
    func updateCollaborativePageTitle(
        pageId: String,
        title: String,
        documentSnapshot: ProseMirrorDocument,
        baseTitle: String,
        baseDocument: ProseMirrorDocument,
        snapshotCapturedAt: Date
    ) async throws -> CollaborativePagePersistenceResult {
        guard let apiClient else {
            return try await persistCollaborativePageLocally(
                pageId: pageId,
                title: title,
                document: documentSnapshot,
                baseTitle: baseTitle,
                baseDocument: baseDocument,
                snapshotCapturedAt: snapshotCapturedAt
            )
        }

        let page: DocmostEditablePage
        do {
            page = try await apiClient.send(.updatePage(
                pageId: pageId,
                title: title
            ))
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            return try await persistCollaborativePageLocally(
                pageId: pageId,
                title: title,
                document: documentSnapshot,
                baseTitle: baseTitle,
                baseDocument: baseDocument,
                snapshotCapturedAt: snapshotCapturedAt
            )
        }

        isOffline = false
        cacheCollaborativeSnapshot(page: page, document: documentSnapshot)

        do {
            let replayDecision = OfflinePageUpdateReplayDecision.resolve(
                serverPage: page,
                queuedTitle: title,
                queuedDocument: documentSnapshot,
                baseTitle: baseTitle,
                baseDocument: baseDocument
            )
            switch replayDecision {
            case .alreadySynchronized, .updateTitleOnly:
                _ = try await acknowledgePendingPageUpdate(
                    pageId: pageId,
                    snapshotCapturedAt: snapshotCapturedAt
                )
                await refreshOfflineMutationCount()
                scheduleOfflineQueueReconciliation()
            case .replaceDocument, .conflict:
                _ = try await supersedePendingPageUpdate(
                    pageId: pageId,
                    title: title,
                    document: documentSnapshot,
                    baseTitle: baseTitle,
                    baseDocument: baseDocument,
                    snapshotCapturedAt: snapshotCapturedAt
                )
                await refreshOfflineMutationCount()
                statusMessage = replayDecision == .conflict ?
                    "Saved locally. A newer remote version must be resolved before this draft can sync." :
                    "Saved locally. Waiting for the collaborative document to sync."
            }
        } catch {
            statusMessage = "Could not make the collaborative document durable: " + error.localizedDescription
            throw error
        }
        return CollaborativePagePersistenceResult(
            page: page,
            persistedTitle: page.title,
            updatedAt: page.updatedAt
        )
    }

    // swiftlint:disable:next function_parameter_count
    func persistDeferredCollaborativeDraft(
        pageId: String,
        title: String,
        documentSnapshot: ProseMirrorDocument,
        baseTitle: String,
        baseDocument: ProseMirrorDocument,
        snapshotCapturedAt: Date
    ) async throws -> CollaborativePagePersistenceResult {
        try await persistCollaborativePageLocally(
            pageId: pageId,
            title: title,
            document: documentSnapshot,
            baseTitle: baseTitle,
            baseDocument: baseDocument,
            snapshotCapturedAt: snapshotCapturedAt
        )
    }
}

private extension AppState {
    func cacheCollaborativeSnapshot(page: DocmostEditablePage, document: ProseMirrorDocument) {
        guard let cacheScope else { return }
        let cachedPage = DocmostEditablePage(
            id: page.id,
            slugId: page.slugId,
            title: page.title,
            content: document,
            icon: page.icon,
            spaceId: page.spaceId,
            createdAt: page.createdAt,
            updatedAt: page.updatedAt,
            permissions: page.permissions,
            creator: page.creator,
            lastUpdatedBy: page.lastUpdatedBy
        )
        scheduleCacheWrite(.saveEditablePage(cachedPage, scope: cacheScope))
    }

    // swiftlint:disable:next function_parameter_count
    func supersedePendingPageUpdate(
        pageId: String,
        title: String,
        document: ProseMirrorDocument,
        baseTitle: String,
        baseDocument: ProseMirrorDocument,
        snapshotCapturedAt: Date
    ) async throws -> OfflinePageUpdateSupersessionResult {
        guard let cacheScope else {
            throw APIError.connectionFailed("Offline document durability is unavailable until you sign in.")
        }
        if let offlineQueueRepository {
            return try await offlineQueueRepository.supersedePendingPageUpdate(
                pageId: pageId,
                title: title,
                document: document,
                baseTitle: baseTitle,
                baseDocument: baseDocument,
                snapshotCapturedAt: snapshotCapturedAt,
                scope: cacheScope
            )
        }
        guard let offlineQueue else {
            throw APIError.connectionFailed("Offline document durability is unavailable on this device.")
        }
        return try offlineQueue.supersedePendingPageUpdate(
            pageId: pageId,
            title: title,
            document: document,
            baseTitle: baseTitle,
            baseDocument: baseDocument,
            snapshotCapturedAt: snapshotCapturedAt,
            scope: cacheScope
        )
    }

    func acknowledgePendingPageUpdate(
        pageId: String,
        snapshotCapturedAt: Date
    ) async throws -> OfflinePageUpdateAcknowledgementResult {
        guard let cacheScope else { return .noPendingUpdate }
        if let offlineQueueRepository {
            return try await offlineQueueRepository.acknowledgePendingPageUpdate(
                pageId: pageId,
                snapshotCapturedAt: snapshotCapturedAt,
                scope: cacheScope
            )
        }
        guard let offlineQueue else { return .noPendingUpdate }
        return try offlineQueue.acknowledgePendingPageUpdate(
            pageId: pageId,
            snapshotCapturedAt: snapshotCapturedAt,
            scope: cacheScope
        )
    }

    // swiftlint:disable:next function_parameter_count
    func persistCollaborativePageLocally(
        pageId: String,
        title: String,
        document: ProseMirrorDocument,
        baseTitle: String,
        baseDocument: ProseMirrorDocument,
        snapshotCapturedAt: Date
    ) async throws -> CollaborativePagePersistenceResult {
        let supersessionResult = try await supersedePendingPageUpdate(
            pageId: pageId,
            title: title,
            document: document,
            baseTitle: baseTitle,
            baseDocument: baseDocument,
            snapshotCapturedAt: snapshotCapturedAt
        )
        await refreshOfflineMutationCount()

        guard supersessionResult != .newerPendingUpdatePreserved else {
            return CollaborativePagePersistenceResult(
                page: nil,
                persistedTitle: title,
                updatedAt: nil
            )
        }

        let page = try await saveLocalEditableDraft(
            pageId: pageId,
            title: title,
            document: document
        )
        return CollaborativePagePersistenceResult(
            page: page,
            persistedTitle: page.title,
            updatedAt: page.updatedAt
        )
    }
}
