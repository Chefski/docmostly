import Foundation
import Testing
@testable import docmostly

@MainActor
struct FavoritesViewModelTests {
    @Test func optimisticRemovalStaysRemovedAfterServerSuccess() async {
        let favorite = pageFavorite(id: "favorite-page")
        let viewModel = FavoritesViewModel()
        viewModel.applyInitialPage(response(items: [favorite]))

        await viewModel.remove(favorite) { }

        #expect(viewModel.favorites.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func optimisticRemovalRestoresOriginalOrderAfterFailure() async {
        let first = pageFavorite(id: "favorite-page")
        let second = spaceFavorite(id: "favorite-space", name: "Product")
        let viewModel = FavoritesViewModel()
        viewModel.applyInitialPage(response(items: [first, second]))

        await viewModel.remove(first) {
            throw FavoriteTestError.failed
        }

        #expect(viewModel.favorites.map(\.id) == [first.id, second.id])
        #expect(viewModel.errorMessage != nil)
    }

    @Test func sectionsRepresentSpacesPagesAndTemplatesWithoutDroppingTypes() {
        let zulu = spaceFavorite(id: "favorite-zulu", name: "Zulu")
        let alpha = spaceFavorite(id: "favorite-alpha", name: "Alpha")
        let page = pageFavorite(id: "favorite-page")
        let template = templateFavorite(id: "favorite-template")
        let viewModel = FavoritesViewModel()
        viewModel.applyInitialPage(response(items: [zulu, page, template, alpha]))

        #expect(viewModel.sections.map(\.type) == [.space, .page, .template])
        #expect(viewModel.sections.first?.favorites.map(\.title) == ["Alpha", "Zulu"])
        #expect(PageOpenTarget(favorite: page)?.slugId == "roadmap")
        #expect(zulu.targetID == "space-1")
        #expect(template.title == "Planning Template")
    }

    private func response(
        items: [DocmostFavorite]
    ) -> PaginatedResponse<DocmostFavorite> {
        PaginatedResponse(
            items: items,
            meta: PaginationMeta(
                limit: 30,
                hasNextPage: false,
                hasPrevPage: false,
                nextCursor: nil,
                prevCursor: nil
            )
        )
    }

    private func pageFavorite(id: String) -> DocmostFavorite {
        DocmostFavorite(
            id: id,
            userId: "user-1",
            pageId: "page-1",
            spaceId: nil,
            templateId: nil,
            type: .page,
            workspaceId: "workspace-1",
            createdAt: .now,
            page: DocmostFavoritePage(
                id: "page-1",
                slugId: "roadmap",
                title: "Roadmap",
                icon: nil,
                spaceId: "space-1"
            ),
            space: DocmostFavoriteSpace(id: "space-1", name: "Product", slug: "product", logo: nil),
            template: nil
        )
    }

    private func spaceFavorite(id: String, name: String) -> DocmostFavorite {
        DocmostFavorite(
            id: id,
            userId: "user-1",
            pageId: nil,
            spaceId: "space-1",
            templateId: nil,
            type: .space,
            workspaceId: "workspace-1",
            createdAt: .now,
            page: nil,
            space: DocmostFavoriteSpace(id: "space-1", name: name, slug: name.lowercased(), logo: nil),
            template: nil
        )
    }

    private func templateFavorite(id: String) -> DocmostFavorite {
        DocmostFavorite(
            id: id,
            userId: "user-1",
            pageId: nil,
            spaceId: nil,
            templateId: "template-1",
            type: .template,
            workspaceId: "workspace-1",
            createdAt: .now,
            page: nil,
            space: nil,
            template: DocmostFavoriteTemplate(
                id: "template-1",
                title: "Planning Template",
                description: nil,
                icon: nil,
                spaceId: nil
            )
        )
    }
}

private enum FavoriteTestError: Error {
    case failed
}
