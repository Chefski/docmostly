import Foundation
import Observation

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

enum PageBrowserScope: String, CaseIterable, Identifiable {
    case recentlyUpdated
    case favorites
    case createdByMe

    var id: Self { self }

    var title: String {
        switch self {
        case .recentlyUpdated:
            "Recently Updated"
        case .favorites:
            "Favorites"
        case .createdByMe:
            "Created by Me"
        }
    }

    var systemImage: String {
        switch self {
        case .recentlyUpdated:
            "clock"
        case .favorites:
            "star"
        case .createdByMe:
            "person"
        }
    }

    var loadingTitle: String {
        switch self {
        case .recentlyUpdated:
            "Loading recent pages"
        case .favorites:
            "Loading favorites"
        case .createdByMe:
            "Loading your pages"
        }
    }

    var emptyTitle: String {
        switch self {
        case .recentlyUpdated:
            "No recently updated pages"
        case .favorites:
            "No favorite pages"
        case .createdByMe:
            "No pages created by you"
        }
    }

    var emptySystemImage: String {
        switch self {
        case .recentlyUpdated:
            "clock"
        case .favorites:
            "star"
        case .createdByMe:
            "person.crop.circle"
        }
    }
}

nonisolated struct PageBrowserItem: Identifiable, Hashable, Sendable {
    let id: String
    let slugId: String
    let title: String
    let icon: String?
    let spaceId: String?
    let subtitle: String
    let updatedAt: Date?

    init(page: DocmostPage, fallbackSpaceName: String) {
        id = page.id
        slugId = page.slugId
        title = page.title.isEmpty ? "Untitled" : page.title
        icon = page.icon
        spaceId = page.spaceId
        subtitle = page.space?.name ?? page.space?.slug ?? fallbackSpaceName
        updatedAt = page.updatedAt
    }

    init?(favorite: DocmostFavorite, fallbackSpaceName: String) {
        guard favorite.type == .page, let slugId = favorite.page?.slugId ?? favorite.pageId else { return nil }

        id = favorite.page?.id ?? favorite.id
        self.slugId = slugId
        title = favorite.page?.title.isEmpty == false ? favorite.page?.title ?? "Untitled" : "Untitled"
        icon = favorite.page?.icon
        spaceId = favorite.page?.spaceId ?? favorite.spaceId
        subtitle = fallbackSpaceName
        updatedAt = favorite.createdAt
    }
}

@MainActor
@Observable
final class PageBrowserViewModel {
    static let defaultPageLimit = 50

    var selectedScope: PageBrowserScope = .recentlyUpdated
    private(set) var items: [PageBrowserItem] = []
    var isLoading = false
    var errorMessage: String?

    func load(space: DocmostSpace, provider: any PageBrowserProviding) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            switch selectedScope {
            case .recentlyUpdated:
                let response = try await provider.loadRecentPages(
                    spaceId: space.id,
                    cursor: nil,
                    limit: Self.defaultPageLimit
                )
                items = response.items.map { PageBrowserItem(page: $0, fallbackSpaceName: space.name) }
            case .favorites:
                let response = try await provider.loadFavorites(
                    type: .page,
                    spaceId: space.id,
                    cursor: nil,
                    limit: Self.defaultPageLimit
                )
                items = response.items.compactMap {
                    PageBrowserItem(favorite: $0, fallbackSpaceName: space.name)
                }
            case .createdByMe:
                let response = try await provider.loadCreatedByPages(
                    userId: provider.currentPageBrowserUserID,
                    spaceId: space.id,
                    cursor: nil,
                    limit: Self.defaultPageLimit
                )
                items = response.items.map { PageBrowserItem(page: $0, fallbackSpaceName: space.name) }
            }
        } catch {
            items = []
            errorMessage = error.localizedDescription
        }
    }
}
