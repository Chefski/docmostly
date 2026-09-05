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

    @Test func changingQueryImmediatelyInvalidatesResultsAndPagination() async {
        let provider = SearchProviderSpy()
        provider.resultsByOffset[0] = (0..<SearchViewModel.defaultPageSize).map { Self.result(id: "page-\($0)") }
        let viewModel = SearchViewModel()
        viewModel.query = "roadmap"
        await viewModel.search(provider: provider)

        viewModel.query = "release"
        await viewModel.loadMore(provider: provider)

        #expect(viewModel.results.isEmpty)
        #expect(viewModel.hasMoreResults == false)
        #expect(viewModel.hasCompletedSearch == false)
        #expect(provider.requests.count == 1)
    }

    @Test func changingResolvedSpacePreventsPaginationFromPreviousSpace() async {
        let provider = SearchProviderSpy()
        provider.selectedSpaceID = "space-1"
        provider.resultsByOffset[0] = (0..<SearchViewModel.defaultPageSize).map { Self.result(id: "page-\($0)") }
        let viewModel = SearchViewModel()
        viewModel.query = "roadmap"
        await viewModel.search(provider: provider)
        let originalKey = viewModel.taskKey(provider: provider)

        provider.selectedSpaceID = "space-2"
        await viewModel.loadMore(provider: provider)

        #expect(viewModel.taskKey(provider: provider) != originalKey)
        #expect(provider.requests.count == 1)
    }

    @Test func olderRequestCannotEndNewerLoadingStateOrPublishAnError() async {
        let provider = SearchProviderSpy()
        provider.suspendsRequests = true
        let viewModel = SearchViewModel()
        viewModel.query = "roadmap"
        let older = Task { await viewModel.search(provider: provider) }
        await provider.waitForRequestCount(1)
        let newer = Task { await viewModel.search(provider: provider) }
        await provider.waitForRequestCount(2)

        provider.completeRequest(at: 0, with: .failure(URLError(.timedOut)))
        await older.value
        #expect(viewModel.isSearching)
        #expect(viewModel.errorMessage == nil)

        provider.completeRequest(at: 1, with: .success([Self.result(id: "new")]))
        await newer.value
        #expect(viewModel.results.map(\.id) == ["new"])
        #expect(viewModel.isSearching == false)
    }

    @Test func olderSuccessCannotReplaceNewerResultsForSameQuery() async {
        let provider = SearchProviderSpy()
        provider.suspendsRequests = true
        let viewModel = SearchViewModel()
        viewModel.query = "roadmap"
        let older = Task { await viewModel.search(provider: provider) }
        await provider.waitForRequestCount(1)
        let newer = Task { await viewModel.search(provider: provider) }
        await provider.waitForRequestCount(2)

        provider.completeRequest(at: 1, with: .success([Self.result(id: "new")]))
        await newer.value
        provider.completeRequest(at: 0, with: .success([Self.result(id: "old")]))
        await older.value

        #expect(viewModel.results.map(\.id) == ["new"])
    }

    @Test func clearingQueryRejectsInFlightResponseWithoutAnotherSearch() async {
        let provider = SearchProviderSpy()
        provider.suspendsRequests = true
        let viewModel = SearchViewModel()
        viewModel.query = "roadmap"
        let search = Task { await viewModel.search(provider: provider) }
        await provider.waitForRequestCount(1)

        viewModel.query = ""
        #expect(viewModel.isSearching == false)
        provider.completeRequest(at: 0, with: .success([Self.result(id: "old")]))
        await search.value

        #expect(viewModel.results.isEmpty)
        #expect(viewModel.hasCompletedSearch == false)
    }

    @Test func cancelledRequestCannotPublishResultsEvenWhenProviderCompletes() async {
        let provider = SearchProviderSpy()
        provider.suspendsRequests = true
        let viewModel = SearchViewModel()
        viewModel.query = "roadmap"
        let search = Task { await viewModel.search(provider: provider) }
        await provider.waitForRequestCount(1)

        search.cancel()
        provider.completeRequest(at: 0, with: .success([Self.result(id: "cancelled")]))
        await search.value

        #expect(viewModel.results.isEmpty)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.isSearching == false)
        #expect(viewModel.hasCompletedSearch == false)
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
    var suspendsRequests = false
    private var pendingRequests: [Int: CheckedContinuation<[DocmostSearchResult], any Error>] = [:]
    private var requestWaiter: CheckedContinuation<Void, Never>?
    private var awaitedRequestCount = 0

    func waitForRequestCount(_ count: Int) async {
        guard requests.count < count else { return }
        awaitedRequestCount = count
        await withCheckedContinuation { requestWaiter = $0 }
    }

    func completeRequest(at index: Int, with result: Result<[DocmostSearchResult], any Error>) {
        pendingRequests.removeValue(forKey: index)?.resume(with: result)
    }

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
        if suspendsRequests {
            return try await withCheckedThrowingContinuation { continuation in
                pendingRequests[requests.count - 1] = continuation
                if requests.count >= awaitedRequestCount {
                    requestWaiter?.resume()
                    requestWaiter = nil
                }
            }
        }
        return resultsByOffset[offset] ?? []
    }
}
