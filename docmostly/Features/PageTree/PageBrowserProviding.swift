import Foundation

@MainActor
protocol PageBrowserProviding: AnyObject {
    var currentPageBrowserUserID: String? { get }

    func loadRecentPages(
        spaceId: String?,
        cursor: String?,
        limit: Int
    ) async throws -> PaginatedResponse<DocmostPage>

    func loadCreatedByPages(
        userId: String?,
        spaceId: String?,
        cursor: String?,
        limit: Int
    ) async throws -> PaginatedResponse<DocmostPage>

    func loadFavorites(
        type: FavoriteType?,
        spaceId: String?,
        cursor: String?,
        limit: Int
    ) async throws -> PaginatedResponse<DocmostFavorite>
}

extension AppState: PageBrowserProviding {
    var currentPageBrowserUserID: String? {
        currentUser?.user.id
    }
}
