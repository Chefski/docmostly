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
            throw APIError.connectionFailed(
                "Offline document edits require the local collaborative document store."
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
            markPageDiscoveryChanged()
            return page
        } catch {
            throw error
        }
    }

    func updateCollaborativePageTitle(
        pageId: String,
        title: String,
        documentSnapshot: ProseMirrorDocument,
        baseTitle: String,
        snapshotCapturedAt: Date
    ) async throws -> CollaborativePagePersistenceResult {
        guard let apiClient else {
            return try await persistCRDTPageLocally(
                pageId: pageId,
                title: title,
                document: documentSnapshot,
                baseTitle: baseTitle,
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
            return try await persistCRDTPageLocally(
                pageId: pageId,
                title: title,
                document: documentSnapshot,
                baseTitle: baseTitle,
                snapshotCapturedAt: snapshotCapturedAt
            )
        }

        isOffline = false
        cacheCollaborativeSnapshot(page: page, document: documentSnapshot)

        do {
            _ = try await acknowledgePendingPageUpdate(
                pageId: pageId,
                snapshotCapturedAt: snapshotCapturedAt
            )
            await refreshOfflineMutationCount()
            scheduleOfflineQueueReconciliation()
        } catch {
            statusMessage = "Could not make the collaborative document durable: " + error.localizedDescription
            throw error
        }
        markPageDiscoveryChanged()
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
        _ = baseDocument
        _ = snapshotCapturedAt
        try await queuePageMetadataUpdate(pageId: pageId, title: title, baseTitle: baseTitle)
        await refreshOfflineMutationCount()

        let page = try await saveLocalEditableDraft(
            pageId: pageId,
            title: title,
            document: document
        )
        markPageDiscoveryChanged()
        return CollaborativePagePersistenceResult(
            page: page,
            persistedTitle: page.title,
            updatedAt: page.updatedAt
        )
    }

    func persistCRDTPageLocally(
        pageId: String,
        title: String,
        document: ProseMirrorDocument,
        baseTitle: String,
        snapshotCapturedAt: Date
    ) async throws -> CollaborativePagePersistenceResult {
        _ = snapshotCapturedAt
        try await queuePageMetadataUpdate(pageId: pageId, title: title, baseTitle: baseTitle)
        await refreshOfflineMutationCount()

        let page = try await saveLocalEditableDraft(pageId: pageId, title: title, document: document)
        markPageDiscoveryChanged()
        return CollaborativePagePersistenceResult(
            page: page,
            persistedTitle: page.title,
            updatedAt: page.updatedAt
        )
    }

    func queuePageMetadataUpdate(pageId: String, title: String, baseTitle: String?) async throws {
        guard title != baseTitle else { return }
        _ = try await queueOfflineMutation(.updatePageMetadata(
            pageId: pageId,
            title: title,
            baseTitle: baseTitle
        ))
    }
}
