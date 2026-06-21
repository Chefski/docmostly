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
            let pages = recentCachedPages(limit: limit)
            return PaginatedResponse(
                items: pages.map { $0.asPage() },
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
            let pages = recentCachedPages(limit: limit)
            return PaginatedResponse(
                items: pages.map { $0.asPage() },
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
            throw APIError.connectionFailed("Favorites require a network connection.")
        }

        let favoriteIds: [String] = try await apiClient.send(.favoriteIds(type: type, spaceId: spaceId))
        isOffline = false
        return favoriteIds
    }

    func addFavorite(
        type: FavoriteType,
        pageId: String? = nil,
        spaceId: String? = nil,
        templateId: String? = nil
    ) async throws {
        guard let apiClient else {
            throw APIError.connectionFailed("Favorites require a network connection.")
        }

        try await apiClient.sendVoid(.addFavorite(
            type: type,
            pageId: pageId,
            spaceId: spaceId,
            templateId: templateId
        ))
        isOffline = false
    }

    func removeFavorite(
        type: FavoriteType,
        pageId: String? = nil,
        spaceId: String? = nil,
        templateId: String? = nil
    ) async throws {
        guard let apiClient else {
            throw APIError.connectionFailed("Favorites require a network connection.")
        }

        try await apiClient.sendVoid(.removeFavorite(
            type: type,
            pageId: pageId,
            spaceId: spaceId,
            templateId: templateId
        ))
        isOffline = false
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
            throw APIError.connectionFailed("Labels require a network connection.")
        }

        let labels: [DocmostLabel] = try await apiClient.send(.pageLabels(pageId: pageId))
        isOffline = false
        return labels
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
            throw APIError.connectionFailed("Labels require a network connection.")
        }

        let labels: [DocmostLabel] = try await apiClient.send(.addPageLabels(pageId: pageId, names: names))
        isOffline = false
        return labels
    }

    func removePageLabel(pageId: String, labelId: String) async throws {
        guard let apiClient else {
            throw APIError.connectionFailed("Labels require a network connection.")
        }

        try await apiClient.sendVoid(.removePageLabel(pageId: pageId, labelId: labelId))
        isOffline = false
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
            throw APIError.connectionFailed("Watch status requires a network connection.")
        }

        let response: WatchStatusResponse = try await apiClient.send(.watchPage(pageId: pageId))
        isOffline = false
        return response
    }

    func unwatchPage(pageId: String) async throws -> WatchStatusResponse {
        guard let apiClient else {
            throw APIError.connectionFailed("Watch status requires a network connection.")
        }

        let response: WatchStatusResponse = try await apiClient.send(.unwatchPage(pageId: pageId))
        isOffline = false
        return response
    }

    func loadPageWatchStatus(pageId: String) async throws -> WatchStatusResponse {
        guard let apiClient else {
            throw APIError.connectionFailed("Watch status requires a network connection.")
        }

        let response: WatchStatusResponse = try await apiClient.send(.pageWatchStatus(pageId: pageId))
        isOffline = false
        return response
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
            throw APIError.connectionFailed("Space watch status requires a network connection.")
        }

        let response: WatchStatusResponse = try await apiClient.send(.watchSpace(spaceId: spaceId))
        isOffline = false
        return response
    }

    func unwatchSpace(spaceId: String) async throws -> WatchStatusResponse {
        guard let apiClient else {
            throw APIError.connectionFailed("Space watch status requires a network connection.")
        }

        let response: WatchStatusResponse = try await apiClient.send(.unwatchSpace(spaceId: spaceId))
        isOffline = false
        return response
    }

    func loadSpaceWatchStatus(spaceId: String) async throws -> WatchStatusResponse {
        guard let apiClient else {
            throw APIError.connectionFailed("Space watch status requires a network connection.")
        }

        let response: WatchStatusResponse = try await apiClient.send(.spaceWatchStatus(spaceId: spaceId))
        isOffline = false
        return response
    }

}
