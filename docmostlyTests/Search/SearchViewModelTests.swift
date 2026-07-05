import Foundation
import Testing
@testable import docmostly

@MainActor
struct SearchViewModelTests {
    @Test func searchesCurrentSpaceByDefault() async throws {
        let provider = SearchProviderSpy()
        provider.selectedSpaceID = "space-1"
        provider.resultsByOffset[0] = [Self.result(id: "page-1")]
        let viewModel = SearchViewModel()
        viewModel.query = "roadmap"

        await viewModel.search(provider: provider)

        #expect(viewModel.results.map(\.id) == ["page-1"])
        #expect(viewModel.hasMoreResults == false)
        #expect(provider.requests == [
            SearchProviderSpy.Request(
                query: "roadmap",
                spaceId: "space-1",
                creatorId: nil,
                limit: SearchViewModel.defaultPageSize,
                offset: 0
            )
        ])
    }

    @Test func loadsAdditionalPagesWithOffset() async throws {
        let provider = SearchProviderSpy()
        provider.selectedSpaceID = "space-1"
        provider.resultsByOffset[0] = (0..<SearchViewModel.defaultPageSize).map { Self.result(id: "page-\($0)") }
        provider.resultsByOffset[SearchViewModel.defaultPageSize] = [Self.result(id: "page-25")]
        let viewModel = SearchViewModel()
        viewModel.query = "roadmap"

        await viewModel.search(provider: provider)
        await viewModel.loadMore(provider: provider)

        #expect(viewModel.results.count == SearchViewModel.defaultPageSize + 1)
        #expect(viewModel.hasMoreResults == false)
        #expect(provider.requests.map(\.offset) == [0, SearchViewModel.defaultPageSize])
    }

    @Test func loadMoreAdvancesOffsetByFetchedRowsWhenDuplicatesAreDropped() async throws {
        let provider = SearchProviderSpy()
        provider.selectedSpaceID = "space-1"
        provider.resultsByOffset[0] = (0..<SearchViewModel.defaultPageSize).map { Self.result(id: "page-\($0)") }
        provider.resultsByOffset[SearchViewModel.defaultPageSize] = (0..<SearchViewModel.defaultPageSize).map {
            Self.result(id: "page-\($0)")
        }
        provider.resultsByOffset[SearchViewModel.defaultPageSize * 2] = [Self.result(id: "page-50")]
        let viewModel = SearchViewModel()
        viewModel.query = "roadmap"

        await viewModel.search(provider: provider)
        await viewModel.loadMore(provider: provider)
        await viewModel.loadMore(provider: provider)

        #expect(viewModel.results.count == SearchViewModel.defaultPageSize + 1)
        #expect(provider.requests.map(\.offset) == [
            0,
            SearchViewModel.defaultPageSize,
            SearchViewModel.defaultPageSize * 2
        ])
    }

    @Test func resolvesAllSpacesAndCurrentUserScopes() async throws {
        let provider = SearchProviderSpy()
        provider.selectedSpaceID = "space-1"
        provider.currentSearchUserID = "user-1"
        provider.resultsByOffset[0] = [Self.result(id: "page-1")]
        let viewModel = SearchViewModel()
        viewModel.query = "roadmap"
        viewModel.spaceScope = .allSpaces
        viewModel.authorScope = .currentUser

        await viewModel.search(provider: provider)

        #expect(provider.requests == [
            SearchProviderSpy.Request(
                query: "roadmap",
                spaceId: nil,
                creatorId: "user-1",
                limit: SearchViewModel.defaultPageSize,
                offset: 0
            )
        ])
    }

    private static func result(id: String) -> DocmostSearchResult {
        DocmostSearchResult(
            id: id,
            title: "Roadmap",
            icon: nil,
            parentPageId: nil,
            slugId: "\(id)-slug",
            creatorId: "user-1",
            createdAt: nil,
            updatedAt: nil,
            rank: 1,
            highlight: "Quarterly <b>roadmap</b>",
            space: SearchResultSpace(id: "space-1", name: "Product", slug: "product", icon: nil)
        )
    }
}

@MainActor
private final class SearchProviderSpy: SearchProviding {
    struct Request: Equatable {
        let query: String
        let spaceId: String?
        let creatorId: String?
        let limit: Int
        let offset: Int
    }

    var selectedSpaceID: String?
    var currentSearchUserID: String?
    var resultsByOffset: [Int: [DocmostSearchResult]] = [:]
    private(set) var requests: [Request] = []

    func search(
        query: String,
        spaceId: String?,
        creatorId: String?,
        limit: Int,
        offset: Int
    ) async throws -> [DocmostSearchResult] {
        requests.append(Request(
            query: query,
            spaceId: spaceId,
            creatorId: creatorId,
            limit: limit,
            offset: offset
        ))
        return resultsByOffset[offset] ?? []
    }
}
