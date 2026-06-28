import Foundation

extension AppState {
    func loadPageBreadcrumbs(pageId: String) async throws -> [DocmostPage] {
        guard let apiClient else {
            throw APIError.connectionFailed("Breadcrumbs require a network connection.")
        }

        let response: [DocmostPage] = try await apiClient.send(.pageBreadcrumbs(pageId: pageId))
        isOffline = false
        return response
    }

    func loadRecentPages(
        spaceId: String? = nil,
        cursor: String? = nil,
        limit: Int = 20
    ) async throws -> PaginatedResponse<DocmostPage> {
        guard let apiClient else {
            let pages = await recentCachedPages(limit: limit)
            return PaginatedResponse(
                items: pages,
                meta: PaginationMeta(
                    limit: limit,
                    hasNextPage: false,
                    hasPrevPage: false,
                    nextCursor: nil,
                    prevCursor: nil
                )
            )
        }

        do {
            let response: PaginatedResponse<DocmostPage> = try await apiClient.send(.recentPages(
                spaceId: spaceId,
                cursor: cursor,
                limit: limit
            ))
            isOffline = false
            return response
        } catch {
            isOffline = true
            statusMessage = error.localizedDescription
            guard canUseOfflineCache(after: error) else { throw error }
            let pages = await recentCachedPages(limit: limit)
            return PaginatedResponse(
                items: pages,
                meta: PaginationMeta(
                    limit: limit,
                    hasNextPage: false,
                    hasPrevPage: false,
                    nextCursor: nil,
                    prevCursor: nil
                )
            )
        }
    }

    func loadFavorites(
        type: FavoriteType? = nil,
        spaceId: String? = nil,
        cursor: String? = nil,
        limit: Int = 20
    ) async throws -> PaginatedResponse<DocmostFavorite> {
        guard let apiClient else {
            throw APIError.connectionFailed("Favorites require a network connection.")
        }

        let response: PaginatedResponse<DocmostFavorite> = try await apiClient.send(.favorites(
            type: type,
            spaceId: spaceId,
            cursor: cursor,
            limit: limit
        ))
        isOffline = false
        return response
    }

    func loadFavoriteIds(type: FavoriteType, spaceId: String? = nil) async throws -> [String] {
        guard let apiClient else {
            return Array(favoriteIDsByType[type] ?? [])
        }

        do {
            let favoriteIds: [String] = try await apiClient.send(.favoriteIds(type: type, spaceId: spaceId))
            favoriteIDsByType[type] = Set(favoriteIds)
            isOffline = false
            scheduleOfflineQueueReconciliation()
            return favoriteIds
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            return Array(favoriteIDsByType[type] ?? [])
        }
    }

    func addFavorite(
        type: FavoriteType,
        pageId: String? = nil,
        spaceId: String? = nil,
        templateId: String? = nil
    ) async throws {
        guard let apiClient else {
            try await queueFavorite(
                isFavorite: true,
                type: type,
                pageId: pageId,
                spaceId: spaceId,
                templateId: templateId
            )
            return
        }

        do {
            try await apiClient.sendVoid(.addFavorite(
                type: type,
                pageId: pageId,
                spaceId: spaceId,
                templateId: templateId
            ))
            setProjectedFavorite(type: type, pageId: pageId, spaceId: spaceId, templateId: templateId, isFavorite: true)
            isOffline = false
            scheduleOfflineQueueReconciliation()
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            try await queueFavorite(
                isFavorite: true,
                type: type,
                pageId: pageId,
                spaceId: spaceId,
                templateId: templateId
            )
        }
    }

    func removeFavorite(
        type: FavoriteType,
        pageId: String? = nil,
        spaceId: String? = nil,
        templateId: String? = nil
    ) async throws {
        guard let apiClient else {
            try await queueFavorite(
                isFavorite: false,
                type: type,
                pageId: pageId,
                spaceId: spaceId,
                templateId: templateId
            )
            return
        }

        do {
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
            isOffline = false
            scheduleOfflineQueueReconciliation()
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            try await queueFavorite(
                isFavorite: false,
                type: type,
                pageId: pageId,
                spaceId: spaceId,
                templateId: templateId
            )
        }
    }

    func loadNotifications(
        type: NotificationListType = .all,
        cursor: String? = nil,
        limit: Int = 20
    ) async throws -> PaginatedResponse<DocmostNotification> {
        guard let apiClient else {
            throw APIError.connectionFailed("Notifications require a network connection.")
        }

        let response: PaginatedResponse<DocmostNotification> = try await apiClient.send(.notifications(
            type: type,
            cursor: cursor,
            limit: limit
        ))
        isOffline = false
        return response
    }

    func loadUnreadNotificationCount() async throws -> Int {
        guard let apiClient else {
            throw APIError.connectionFailed("Notifications require a network connection.")
        }

        let response: UnreadNotificationCountResponse = try await apiClient.send(.unreadNotificationCount)
        isOffline = false
        return response.count
    }

    func markNotificationsRead(notificationIds: [String]) async throws {
        guard let apiClient else {
            throw APIError.connectionFailed("Notifications require a network connection.")
        }

        try await apiClient.sendVoid(.markNotificationsRead(notificationIds: notificationIds))
        isOffline = false
    }

    func markAllNotificationsRead() async throws {
        guard let apiClient else {
            throw APIError.connectionFailed("Notifications require a network connection.")
        }

        try await apiClient.sendVoid(.markAllNotificationsRead)
        isOffline = false
    }

    func loadPageLabels(pageId: String) async throws -> [DocmostLabel] {
        guard let apiClient else {
            return pageLabelsByID[pageId] ?? []
        }

        do {
            let labels: [DocmostLabel] = try await apiClient.send(.pageLabels(pageId: pageId))
            pageLabelsByID[pageId] = labels
            isOffline = false
            scheduleOfflineQueueReconciliation()
            return labels
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            return pageLabelsByID[pageId] ?? []
        }
    }

    func loadWorkspaceLabels(
        type: LabelType = .page,
        query: String? = nil,
        cursor: String? = nil,
        limit: Int = 50
    ) async throws -> PaginatedResponse<DocmostLabel> {
        guard let apiClient else {
            throw APIError.connectionFailed("Labels require a network connection.")
        }

        let response: PaginatedResponse<DocmostLabel> = try await apiClient.send(.workspaceLabels(
            type: type,
            query: query,
            cursor: cursor,
            limit: limit
        ))
        isOffline = false
        return response
    }

    func addPageLabels(pageId: String, names: [String]) async throws -> [DocmostLabel] {
        guard let apiClient else {
            return try await queuePageLabels(pageId: pageId, names: names)
        }

        do {
            let labels: [DocmostLabel] = try await apiClient.send(.addPageLabels(pageId: pageId, names: names))
            pageLabelsByID[pageId] = labels
            isOffline = false
            scheduleOfflineQueueReconciliation()
            return labels
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            return try await queuePageLabels(pageId: pageId, names: names)
        }
    }

    func removePageLabel(pageId: String, labelId: String) async throws {
        guard let apiClient else {
            try await queueRemovePageLabel(pageId: pageId, labelId: labelId)
            return
        }

        do {
            try await apiClient.sendVoid(.removePageLabel(pageId: pageId, labelId: labelId))
            pageLabelsByID[pageId]?.removeAll { $0.id == labelId }
            isOffline = false
            scheduleOfflineQueueReconciliation()
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            try await queueRemovePageLabel(pageId: pageId, labelId: labelId)
        }
    }

    func loadLabelPages(
        labelId: String? = nil,
        name: String? = nil,
        spaceId: String? = nil,
        query: String? = nil,
        cursor: String? = nil,
        limit: Int = 20
    ) async throws -> PaginatedResponse<DocmostLabeledPage> {
        guard let apiClient else {
            throw APIError.connectionFailed("Labels require a network connection.")
        }

        let response: PaginatedResponse<DocmostLabeledPage> = try await apiClient.send(.labelPages(
            labelId: labelId,
            name: name,
            spaceId: spaceId,
            query: query,
            cursor: cursor,
            limit: limit
        ))
        isOffline = false
        return response
    }

    func watchPage(pageId: String) async throws -> WatchStatusResponse {
        guard let apiClient else {
            return try await queuePageWatch(pageId: pageId, watching: true)
        }

        do {
            let response: WatchStatusResponse = try await apiClient.send(.watchPage(pageId: pageId))
            pageWatchStatusByID[pageId] = response.watching
            isOffline = false
            scheduleOfflineQueueReconciliation()
            return response
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            return try await queuePageWatch(pageId: pageId, watching: true)
        }
    }

    func unwatchPage(pageId: String) async throws -> WatchStatusResponse {
        guard let apiClient else {
            return try await queuePageWatch(pageId: pageId, watching: false)
        }

        do {
            let response: WatchStatusResponse = try await apiClient.send(.unwatchPage(pageId: pageId))
            pageWatchStatusByID[pageId] = response.watching
            isOffline = false
            scheduleOfflineQueueReconciliation()
            return response
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            return try await queuePageWatch(pageId: pageId, watching: false)
        }
    }

    func loadPageWatchStatus(pageId: String) async throws -> WatchStatusResponse {
        guard let apiClient else {
            return WatchStatusResponse(watching: pageWatchStatusByID[pageId] ?? false)
        }

        do {
            let response: WatchStatusResponse = try await apiClient.send(.pageWatchStatus(pageId: pageId))
            pageWatchStatusByID[pageId] = response.watching
            isOffline = false
            scheduleOfflineQueueReconciliation()
            return response
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            return WatchStatusResponse(watching: pageWatchStatusByID[pageId] ?? false)
        }
    }

    func loadWatchedSpaceIds() async throws -> PaginatedResponse<String> {
        guard let apiClient else {
            throw APIError.connectionFailed("Space watch status requires a network connection.")
        }

        let response: PaginatedResponse<String> = try await apiClient.send(.watchedSpaceIds)
        isOffline = false
        return response
    }

    func watchSpace(spaceId: String) async throws -> WatchStatusResponse {
        guard let apiClient else {
            return try await queueSpaceWatch(spaceId: spaceId, watching: true)
        }

        do {
            let response: WatchStatusResponse = try await apiClient.send(.watchSpace(spaceId: spaceId))
            spaceWatchStatusByID[spaceId] = response.watching
            isOffline = false
            scheduleOfflineQueueReconciliation()
            return response
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            return try await queueSpaceWatch(spaceId: spaceId, watching: true)
        }
    }

    func unwatchSpace(spaceId: String) async throws -> WatchStatusResponse {
        guard let apiClient else {
            return try await queueSpaceWatch(spaceId: spaceId, watching: false)
        }

        do {
            let response: WatchStatusResponse = try await apiClient.send(.unwatchSpace(spaceId: spaceId))
            spaceWatchStatusByID[spaceId] = response.watching
            isOffline = false
            scheduleOfflineQueueReconciliation()
            return response
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            return try await queueSpaceWatch(spaceId: spaceId, watching: false)
        }
    }

    func loadSpaceWatchStatus(spaceId: String) async throws -> WatchStatusResponse {
        guard let apiClient else {
            return WatchStatusResponse(watching: spaceWatchStatusByID[spaceId] ?? false)
        }

        do {
            let response: WatchStatusResponse = try await apiClient.send(.spaceWatchStatus(spaceId: spaceId))
            spaceWatchStatusByID[spaceId] = response.watching
            isOffline = false
            scheduleOfflineQueueReconciliation()
            return response
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            return WatchStatusResponse(watching: spaceWatchStatusByID[spaceId] ?? false)
        }
    }

    private func queueFavorite(
        isFavorite: Bool,
        type: FavoriteType,
        pageId: String?,
        spaceId: String?,
        templateId: String?
    ) async throws {
        let payload: OfflineMutationPayload = if isFavorite {
            .addFavorite(type: type, pageId: pageId, spaceId: spaceId, templateId: templateId)
        } else {
            .removeFavorite(type: type, pageId: pageId, spaceId: spaceId, templateId: templateId)
        }
        try await queueOfflineMutation(payload)
        setProjectedFavorite(
            type: type,
            pageId: pageId,
            spaceId: spaceId,
            templateId: templateId,
            isFavorite: isFavorite
        )
    }

    private func queuePageLabels(pageId: String, names: [String]) async throws -> [DocmostLabel] {
        let existingLabels = pageLabelsByID[pageId] ?? []
        let existingNames = Set(existingLabels.map(\.name))
        let offlineLabels = names
            .filter { existingNames.contains($0) == false }
            .map { OfflinePageLabel(pageId: pageId, name: $0) }

        guard offlineLabels.isEmpty == false else {
            return existingLabels
        }

        try await queueOfflineMutation(.addPageLabels(pageId: pageId, labels: offlineLabels))

        let now = Date.now
        let localLabels = offlineLabels
            .map { label in
                DocmostLabel(
                    id: label.id,
                    name: label.name,
                    type: .page,
                    workspaceId: currentUser?.workspace.id,
                    createdAt: now,
                    updatedAt: now
                )
            }
        let labels = existingLabels + localLabels
        pageLabelsByID[pageId] = labels
        return labels
    }

    private func queueRemovePageLabel(pageId: String, labelId: String) async throws {
        if labelId.hasPrefix("offline-label-") {
            try await removePendingOfflineLabelProjection(pageId: pageId, labelId: labelId)
            pageLabelsByID[pageId]?.removeAll { $0.id == labelId }
            return
        }

        try await queueOfflineMutation(.removePageLabel(pageId: pageId, labelId: labelId))
        pageLabelsByID[pageId]?.removeAll { $0.id == labelId }
    }

    private func queuePageWatch(pageId: String, watching: Bool) async throws -> WatchStatusResponse {
        let payload: OfflineMutationPayload = watching ? .watchPage(pageId: pageId) : .unwatchPage(pageId: pageId)
        try await queueOfflineMutation(payload)
        pageWatchStatusByID[pageId] = watching
        return WatchStatusResponse(watching: watching)
    }

    private func queueSpaceWatch(spaceId: String, watching: Bool) async throws -> WatchStatusResponse {
        let payload: OfflineMutationPayload = watching ? .watchSpace(spaceId: spaceId) : .unwatchSpace(spaceId: spaceId)
        try await queueOfflineMutation(payload)
        spaceWatchStatusByID[spaceId] = watching
        return WatchStatusResponse(watching: watching)
    }
}
