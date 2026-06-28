import Foundation

extension AppState {
    func canQueueOfflineMutation(after error: Error) -> Bool {
        guard let apiError = error as? APIError else {
            return true
        }

        switch apiError {
        case .connectionFailed, .invalidResponse:
            return true
        case .httpStatus(let status, _):
            return status == 408 || status == 429 || status >= 500
        case .missingData, .responseTooLarge:
            return false
        }
    }

    @discardableResult
    func queueOfflineMutation(_ payload: OfflineMutationPayload) async throws -> OfflineMutationRecord {
        let scope = try requireCacheScope(message: "Offline changes are unavailable until you sign in.")
        let record: OfflineMutationRecord
        if let offlineQueueRepository {
            record = try await offlineQueueRepository.enqueue(payload, scope: scope)
        } else if let offlineQueue {
            record = try offlineQueue.enqueue(payload, scope: scope)
        } else {
            throw APIError.connectionFailed("Offline changes are unavailable until local storage is configured.")
        }
        await refreshOfflineMutationCount()
        statusMessage = "Queued offline change. It will sync when the workspace is reachable."
        return record
    }

    func refreshOfflineMutationCount() async {
        guard let cacheScope else {
            pendingOfflineMutationCount = 0
            return
        }

        do {
            if let offlineQueueRepository {
                pendingOfflineMutationCount = try await offlineQueueRepository.count(scope: cacheScope)
            } else {
                pendingOfflineMutationCount = try offlineQueue?.count(scope: cacheScope) ?? 0
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    func scheduleOfflineQueueReconciliation() {
        guard pendingOfflineMutationCount > 0, offlineReplayTask == nil else { return }

        offlineReplayTask = Task { [weak self] in
            await self?.reconcileOfflineMutations()
        }
    }

    func saveLocalEditableDraft(
        pageId: String,
        title: String,
        document: ProseMirrorDocument
    ) async throws -> DocmostEditablePage {
        let scope = try requireCacheScope(message: "This page is not cached for offline editing.")
        if let cacheWriter {
            return try await cacheWriter.saveLocalEditableDraft(
                pageId: pageId,
                title: title,
                document: document,
                scope: scope
            )
        }

        guard let cacheRepository else {
            throw APIError.connectionFailed("This page is not cached for offline editing.")
        }
        return try cacheRepository.saveLocalEditableDraft(
            pageId: pageId,
            title: title,
            document: document,
            scope: scope
        )
    }

    func queuePageUpdate(
        pageId: String,
        title: String,
        document: ProseMirrorDocument
    ) async throws -> DocmostEditablePage {
        try await queueOfflineMutation(.updatePage(pageId: pageId, title: title, document: document))

        do {
            return try await saveLocalEditableDraft(pageId: pageId, title: title, document: document)
        } catch {
            return DocmostEditablePage(
                id: pageId,
                slugId: pageId,
                title: title,
                content: document,
                icon: nil,
                spaceId: "",
                updatedAt: Date.now,
                permissions: DocmostPagePermissions(canEdit: true, hasRestriction: false),
                lastUpdatedBy: currentUser?.user
            )
        }
    }

    func setProjectedFavorite(
        type: FavoriteType,
        pageId: String?,
        spaceId: String?,
        templateId: String?,
        isFavorite: Bool
    ) {
        guard let targetID = pageId ?? spaceId ?? templateId else { return }
        var favoriteIDs = favoriteIDsByType[type] ?? []
        if isFavorite {
            favoriteIDs.insert(targetID)
        } else {
            favoriteIDs.remove(targetID)
        }
        favoriteIDsByType[type] = favoriteIDs
    }

    func cancelOfflineReplay() {
        offlineReplayTask?.cancel()
        offlineReplayTask = nil
    }

    func clearOfflineProjections() {
        pageCommentsByID.removeAll(keepingCapacity: true)
        pageLabelsByID.removeAll(keepingCapacity: true)
        favoriteIDsByType.removeAll(keepingCapacity: true)
        pageWatchStatusByID.removeAll(keepingCapacity: true)
        spaceWatchStatusByID.removeAll(keepingCapacity: true)
    }

    private func reconcileOfflineMutations() async {
        defer {
            offlineReplayTask = nil
        }

        guard let apiClient, let cacheScope else { return }

        do {
            while true {
                let records = try await pendingOfflineMutations(scope: cacheScope, limit: 25)
                guard records.isEmpty == false else {
                    pendingOfflineMutationCount = 0
                    return
                }

                for record in records {
                    do {
                        try await replay(record, using: apiClient)
                        try await removeOfflineMutation(id: record.id, scope: cacheScope)
                        await refreshOfflineMutationCount()
                    } catch {
                        try? await markOfflineMutationFailed(
                            id: record.id,
                            scope: cacheScope,
                            message: error.localizedDescription
                        )
                        await refreshOfflineMutationCount()
                        if canQueueOfflineMutation(after: error) {
                            isOffline = true
                        }
                        statusMessage = "Could not sync queued offline change: \(error.localizedDescription)"
                        return
                    }
                }
            }
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    // swiftlint:disable cyclomatic_complexity
    private func replay(_ record: OfflineMutationRecord, using apiClient: DocmostAPIClient) async throws {
        switch record.payload {
        case .updatePage(let pageId, let title, let document):
            let page: DocmostEditablePage = try await apiClient.send(.updatePage(
                pageId: pageId,
                title: title,
                content: document,
                format: .json,
                operation: .replace
            ))
            scheduleCacheWrite(.saveEditablePage(page, scope: record.scope))
        case .createComment(let pageId, let content, let type, let selection, let yjsSelection):
            let comment: DocmostComment = try await apiClient.send(.createComment(
                pageId: pageId,
                content: content,
                type: type,
                selection: selection,
                yjsSelection: yjsSelection
            ))
            applyReplayedComment(comment)
        case .resolveComment(let commentId, let pageId, let resolved):
            let comment: DocmostComment = try await apiClient.send(.resolveComment(
                commentId: commentId,
                pageId: pageId,
                resolved: resolved
            ))
            applyReplayedComment(comment)
        case .addPageLabels(let pageId, let names):
            let labels: [DocmostLabel] = try await apiClient.send(.addPageLabels(pageId: pageId, names: names))
            pageLabelsByID[pageId] = labels
        case .removePageLabel(let pageId, let labelId):
            try await apiClient.sendVoid(.removePageLabel(pageId: pageId, labelId: labelId))
            pageLabelsByID[pageId]?.removeAll { $0.id == labelId }
        case .addFavorite(let type, let pageId, let spaceId, let templateId):
            try await apiClient.sendVoid(.addFavorite(
                type: type,
                pageId: pageId,
                spaceId: spaceId,
                templateId: templateId
            ))
            setProjectedFavorite(
                type: type,
                pageId: pageId,
                spaceId: spaceId,
                templateId: templateId,
                isFavorite: true
            )
        case .removeFavorite(let type, let pageId, let spaceId, let templateId):
            try await apiClient.sendVoid(.removeFavorite(
                type: type,
                pageId: pageId,
                spaceId: spaceId,
                templateId: templateId
            ))
            setProjectedFavorite(
                type: type,
                pageId: pageId,
                spaceId: spaceId,
                templateId: templateId,
                isFavorite: false
            )
        case .watchPage(let pageId):
            let response: WatchStatusResponse = try await apiClient.send(.watchPage(pageId: pageId))
            pageWatchStatusByID[pageId] = response.watching
        case .unwatchPage(let pageId):
            let response: WatchStatusResponse = try await apiClient.send(.unwatchPage(pageId: pageId))
            pageWatchStatusByID[pageId] = response.watching
        case .watchSpace(let spaceId):
            let response: WatchStatusResponse = try await apiClient.send(.watchSpace(spaceId: spaceId))
            spaceWatchStatusByID[spaceId] = response.watching
        case .unwatchSpace(let spaceId):
            let response: WatchStatusResponse = try await apiClient.send(.unwatchSpace(spaceId: spaceId))
            spaceWatchStatusByID[spaceId] = response.watching
        case .movePage(let pageId, let parentPageId, let position):
            try await apiClient.sendVoid(.movePage(pageId: pageId, parentPageId: parentPageId, position: position))
        case .movePageToSpace(let pageId, let spaceId):
            try await apiClient.sendVoid(.movePageToSpace(pageId: pageId, spaceId: spaceId))
        }
    }
    // swiftlint:enable cyclomatic_complexity

    private func pendingOfflineMutations(scope: CacheScope, limit: Int) async throws -> [OfflineMutationRecord] {
        if let offlineQueueRepository {
            return try await offlineQueueRepository.pending(scope: scope, limit: limit)
        }
        return try offlineQueue?.pending(scope: scope, limit: limit) ?? []
    }

    private func removeOfflineMutation(id: String, scope: CacheScope) async throws {
        if let offlineQueueRepository {
            try await offlineQueueRepository.remove(id: id, scope: scope)
            return
        }
        try offlineQueue?.remove(id: id, scope: scope)
    }

    private func markOfflineMutationFailed(id: String, scope: CacheScope, message: String) async throws {
        if let offlineQueueRepository {
            try await offlineQueueRepository.markFailed(id: id, scope: scope, message: message)
            return
        }
        try offlineQueue?.markFailed(id: id, scope: scope, message: message)
    }

    private func applyReplayedComment(_ comment: DocmostComment) {
        guard var comments = pageCommentsByID[comment.pageId] else { return }
        if let index = comments.firstIndex(where: { $0.id == comment.id }) {
            comments[index] = comment
        } else {
            comments.append(comment)
        }
        pageCommentsByID[comment.pageId] = comments
    }
}
