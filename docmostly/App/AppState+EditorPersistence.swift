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
        baseTitle: String
    ) async throws -> CollaborativePagePersistenceResult {
        let reconciliationMarker: OfflineMutationRecord?
        if cacheScope != nil, offlineQueue != nil || offlineQueueRepository != nil {
            reconciliationMarker = try await queuePageMetadataUpdate(
                pageId: pageId,
                title: title,
                baseTitle: baseTitle
            )
        } else {
            reconciliationMarker = nil
        }
        guard let apiClient else {
            return try await persistCRDTPageLocally(
                pageId: pageId,
                title: title,
                document: documentSnapshot,
                baseTitle: baseTitle
            )
        }

        let page: DocmostEditablePage
        do {
            page = try await apiClient.send(.updatePage(
                pageId: pageId,
                title: title
            ))
        } catch {
            guard canQueueOfflineMutation(after: error) else {
                if let reconciliationMarker {
                    try await removeQueuedOfflineMutation(reconciliationMarker)
                }
                throw error
            }
            isOffline = true
            statusMessage = error.localizedDescription
            return try await persistCRDTPageLocally(
                pageId: pageId,
                title: title,
                document: documentSnapshot,
                baseTitle: baseTitle
            )
        }

        isOffline = false
        cacheCollaborativeSnapshot(page: page, document: documentSnapshot)

        await refreshOfflineMutationCount()
        scheduleOfflineQueueReconciliation()
        markPageDiscoveryChanged()
        return CollaborativePagePersistenceResult(
            page: page,
            persistedTitle: page.title,
            updatedAt: page.updatedAt
        )
    }

    func persistDeferredCollaborativeDraft(
        pageId: String,
        title: String,
        documentSnapshot: ProseMirrorDocument,
        baseTitle: String
    ) async throws -> CollaborativePagePersistenceResult {
        try await persistCollaborativePageLocally(
            pageId: pageId,
            title: title,
            document: documentSnapshot,
            baseTitle: baseTitle
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

    func persistCollaborativePageLocally(
        pageId: String,
        title: String,
        document: ProseMirrorDocument,
        baseTitle: String
    ) async throws -> CollaborativePagePersistenceResult {
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
        baseTitle: String
    ) async throws -> CollaborativePagePersistenceResult {
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

    @discardableResult
    func queuePageMetadataUpdate(
        pageId: String,
        title: String,
        baseTitle: String?
    ) async throws -> OfflineMutationRecord {
        try await queueOfflineMutation(.updatePageMetadata(
            pageId: pageId,
            title: title,
            baseTitle: baseTitle
        ))
    }
}
