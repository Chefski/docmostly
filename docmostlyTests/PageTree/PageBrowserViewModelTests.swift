import Foundation
import Testing
@testable import docmostly

@MainActor
struct PageBrowserViewModelTests {
    @Test func loadsRecentlyUpdatedPagesForSelectedSpace() async throws {
        let provider = PageBrowserProviderSpy()
        provider.recentPages = [Self.page(id: "recent-1", title: "Roadmap")]
        let viewModel = PageBrowserViewModel()

        await viewModel.load(space: Self.space, provider: provider)

        #expect(viewModel.items.map(\.title) == ["Roadmap"])
        #expect(provider.recentRequests == [PageBrowserProviderSpy.Request(spaceId: "space-1", userId: nil)])
    }

    @Test func loadsFavoritePagesForSelectedSpace() async throws {
        let provider = PageBrowserProviderSpy()
        provider.favorites = [Self.favorite(id: "favorite-1", title: "Launch Plan")]
        let viewModel = PageBrowserViewModel()
        viewModel.selectedScope = .favorites

        await viewModel.load(space: Self.space, provider: provider)

        #expect(viewModel.items.map(\.slugId) == ["launch-plan"])
        #expect(viewModel.items.map(\.updatedAt) == [nil])
        #expect(provider.favoriteRequests == [PageBrowserProviderSpy.Request(spaceId: "space-1", userId: nil)])
    }

    @Test func loadsCreatedByMePagesForCurrentUser() async throws {
        let provider = PageBrowserProviderSpy()
        provider.currentPageBrowserUserID = "user-1"
        provider.createdPages = [Self.page(id: "created-1", title: "My Notes")]
        let viewModel = PageBrowserViewModel()
        viewModel.selectedScope = .createdByMe

        await viewModel.load(space: Self.space, provider: provider)

        #expect(viewModel.items.map(\.title) == ["My Notes"])
        #expect(provider.createdRequests == [PageBrowserProviderSpy.Request(spaceId: "space-1", userId: "user-1")])
    }

    private static let space = DocmostSpace(
        id: "space-1",
        name: "Jumpseat",
        description: nil,
        logo: nil,
        slug: "jumpseat",
        hostname: nil,
        creatorId: nil,
        createdAt: nil,
        updatedAt: nil,
        memberCount: nil,
        membership: nil,
        settings: nil
    )

    private static func page(id: String, title: String) -> DocmostPage {
        DocmostPage(
            id: id,
            slugId: "\(id)-slug",
            title: title,
            content: nil,
            icon: nil,
            coverPhoto: nil,
            parentPageId: nil,
            creatorId: "user-1",
            spaceId: "space-1",
            workspaceId: "workspace-1",
            isLocked: nil,
            lastUpdatedById: nil,
            createdAt: nil,
            updatedAt: Date(timeIntervalSince1970: 0),
            deletedAt: nil,
            position: nil,
            hasChildren: false,
            permissions: nil,
            creator: nil,
            lastUpdatedBy: nil,
            contributors: nil,
            space: DocmostPageSpace(id: "space-1", name: "Jumpseat", slug: "jumpseat", logo: nil)
        )
    }

    private static func favorite(id: String, title: String) -> DocmostFavorite {
        DocmostFavorite(
            id: id,
            userId: "user-1",
            pageId: "page-1",
            spaceId: nil,
            templateId: nil,
            type: .page,
            workspaceId: "workspace-1",
            createdAt: Date(timeIntervalSince1970: 0),
            page: DocmostFavoritePage(
                id: "page-1",
                slugId: "launch-plan",
                title: title,
                icon: nil,
                spaceId: "space-1"
            ),
            space: nil,
            template: nil
        )
    }
}

@MainActor
private final class PageBrowserProviderSpy: PageBrowserProviding {
    struct Request: Equatable {
        let spaceId: String?
        let userId: String?
    }

    var currentPageBrowserUserID: String?
    var recentPages: [DocmostPage] = []
    var createdPages: [DocmostPage] = []
    var favorites: [DocmostFavorite] = []
    private(set) var recentRequests: [Request] = []
    private(set) var createdRequests: [Request] = []
    private(set) var favoriteRequests: [Request] = []

    func loadRecentPages(
        spaceId: String?,
        cursor: String?,
        limit: Int
    ) async throws -> PaginatedResponse<DocmostPage> {
        recentRequests.append(Request(spaceId: spaceId, userId: nil))
        return Self.response(items: recentPages, limit: limit)
    }

    func loadCreatedByPages(
        userId: String?,
        spaceId: String?,
        cursor: String?,
        limit: Int
    ) async throws -> PaginatedResponse<DocmostPage> {
        createdRequests.append(Request(spaceId: spaceId, userId: userId))
        return Self.response(items: createdPages, limit: limit)
    }

    func loadFavorites(
        type: FavoriteType?,
        spaceId: String?,
        cursor: String?,
        limit: Int
    ) async throws -> PaginatedResponse<DocmostFavorite> {
        favoriteRequests.append(Request(spaceId: spaceId, userId: nil))
        return Self.response(items: favorites, limit: limit)
    }

    private static func response<Item: Decodable & Sendable>(
        items: [Item],
        limit: Int
    ) -> PaginatedResponse<Item> {
        PaginatedResponse(
            items: items,
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
