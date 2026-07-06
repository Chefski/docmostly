import Foundation

extension AppState {
    func loadPageBacklinkCounts(pageId: String) async throws -> DocmostBacklinkCounts {
        guard let apiClient else {
            throw APIError.connectionFailed("Backlinks require a network connection.")
        }

        let counts: DocmostBacklinkCounts = try await apiClient.send(.pageBacklinkCounts(pageId: pageId))
        isOffline = false
        return counts
    }

    func loadPageBacklinks(
        pageId: String,
        direction: DocmostBacklinkDirection,
        cursor: String? = nil,
        limit: Int = 25
    ) async throws -> PaginatedResponse<DocmostBacklinkPage> {
        guard let apiClient else {
            throw APIError.connectionFailed("Backlinks require a network connection.")
        }

        let response: PaginatedResponse<DocmostBacklinkPage> = try await apiClient.send(.pageBacklinks(
            pageId: pageId,
            direction: direction,
            cursor: cursor,
            limit: limit
        ))
        isOffline = false
        return response
    }
}
