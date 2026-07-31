import Foundation
import Testing
@testable import docmostly

@MainActor
struct FavoritesViewModelTests {
    @Test func urlSessionCancellationDoesNotBecomeLoadError() async {
        let viewModel = FavoritesViewModel()

        await viewModel.load {
            throw URLError(.cancelled)
        }

        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test func replacementLoadWinsWhileEarlierRequestUnwinds() async {
        let first = pageFavorite(id: "favorite-first")
        let replacement = pageFavorite(id: "favorite-replacement")
        let loader = FavoritesLoadStub(
            firstResponse: response(items: [first]),
            replacementResponse: response(items: [replacement])
        )
        let viewModel = FavoritesViewModel()

        let firstLoad = Task {
            await viewModel.load(operation: loader.load)
        }
        while loader.requestCount == 0 {
            await Task.yield()
        }

        await viewModel.load(operation: loader.load)
        loader.finishFirstLoad()
        await firstLoad.value

        #expect(viewModel.favorites.map(\.id) == [replacement.id])
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isLoading == false)
    }

    @Test func optimisticRemovalStaysRemovedAfterServerSuccess() async {
        let favorite = pageFavorite(id: "favorite-page")
        let viewModel = FavoritesViewModel()
        viewModel.applyInitialPage(response(items: [favorite]))

        await viewModel.remove(favorite) { }

        #expect(viewModel.favorites.isEmpty)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func replacementLoadDiscardsAnInFlightNextPage() async {
        let first = pageFavorite(id: "favorite-first")
        let staleNext = pageFavorite(id: "favorite-stale-next")
        let replacement = pageFavorite(id: "favorite-replacement")
        let nextPageLoader = FavoritesNextPageLoadStub(response: response(items: [staleNext]))
        let viewModel = FavoritesViewModel()
        viewModel.applyInitialPage(response(items: [first], nextCursor: "cursor-1"))

        let nextPageTask = Task {
            await viewModel.loadNextPage(operation: nextPageLoader.load)
        }
        while nextPageLoader.hasStarted == false {
            await Task.yield()
        }

        await viewModel.load {
            response(items: [replacement])
        }
        nextPageLoader.finish()
        await nextPageTask.value

        #expect(viewModel.favorites.map(\.id) == [replacement.id])
        #expect(viewModel.isLoadingNextPage == false)
        #expect(viewModel.nextPageErrorMessage == nil)
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
        items: [DocmostFavorite],
        nextCursor: String? = nil
    ) -> PaginatedResponse<DocmostFavorite> {
        PaginatedResponse(
            items: items,
            meta: PaginationMeta(
                limit: 30,
                hasNextPage: nextCursor != nil,
                hasPrevPage: false,
                nextCursor: nextCursor,
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

@MainActor
private final class FavoritesNextPageLoadStub {
    private let response: PaginatedResponse<DocmostFavorite>
    private var continuation: CheckedContinuation<PaginatedResponse<DocmostFavorite>, Never>?
    private(set) var hasStarted = false

    init(response: PaginatedResponse<DocmostFavorite>) {
        self.response = response
    }

    func load(cursor: String) async -> PaginatedResponse<DocmostFavorite> {
        _ = cursor
        hasStarted = true
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func finish() {
        continuation?.resume(returning: response)
        continuation = nil
    }
}

@MainActor
private final class FavoritesLoadStub {
    private let firstResponse: PaginatedResponse<DocmostFavorite>
    private let replacementResponse: PaginatedResponse<DocmostFavorite>
    private var firstContinuation: CheckedContinuation<PaginatedResponse<DocmostFavorite>, Never>?
    private(set) var requestCount = 0

    init(
        firstResponse: PaginatedResponse<DocmostFavorite>,
        replacementResponse: PaginatedResponse<DocmostFavorite>
    ) {
        self.firstResponse = firstResponse
        self.replacementResponse = replacementResponse
    }

    func load() async -> PaginatedResponse<DocmostFavorite> {
        requestCount += 1
        guard requestCount == 1 else { return replacementResponse }

        return await withCheckedContinuation { continuation in
            firstContinuation = continuation
        }
    }

    func finishFirstLoad() {
        firstContinuation?.resume(returning: firstResponse)
        firstContinuation = nil
    }
}

private enum FavoriteTestError: Error {
    case failed
}
