import Foundation
import Observation

@MainActor
protocol SearchProviding: AnyObject {
    var selectedSpaceID: String? { get }
    var currentSearchUserID: String? { get }

    func search(
        query: String,
        spaceId: String?,
        creatorId: String?,
        limit: Int,
        offset: Int
    ) async throws -> [DocmostSearchResult]
}

extension AppState: SearchProviding {
    var currentSearchUserID: String? {
        currentUser?.user.id
    }
}

enum SearchSpaceScope: Hashable {
    case currentSpace
    case allSpaces
    case space(String)

    func resolvedSpaceID(currentSpaceID: String?) -> String? {
        switch self {
        case .currentSpace:
            currentSpaceID
        case .allSpaces:
            nil
        case .space(let id):
            id
        }
    }
}

enum SearchAuthorScope: Hashable {
    case anyone
    case currentUser

    func resolvedCreatorID(currentUserID: String?) -> String? {
        switch self {
        case .anyone:
            nil
        case .currentUser:
            currentUserID
        }
    }
}

@MainActor
@Observable
final class SearchViewModel {
    static let defaultPageSize = 25

    var query = "" {
        didSet {
            if query.trimmingCharacters(in: .whitespacesAndNewlines) !=
                oldValue.trimmingCharacters(in: .whitespacesAndNewlines) {
                invalidateSearch()
            }
        }
    }
    private(set) var results: [DocmostSearchResult] = []
    private(set) var isSearching = false
    private(set) var isLoadingMore = false
    private(set) var hasMoreResults = false
    private(set) var errorMessage: String?
    var spaceScope: SearchSpaceScope = .currentSpace {
        didSet { if spaceScope != oldValue { invalidateSearch() } }
    }
    var authorScope: SearchAuthorScope = .anyone {
        didSet { if authorScope != oldValue { invalidateSearch() } }
    }
    private(set) var hasCompletedSearch = false
    @ObservationIgnored private var activeRequestID = UUID()
    @ObservationIgnored private var completedRequestKey: SearchTaskKey?
    private var requestedResultCount = 0

    func taskKey(provider: any SearchProviding) -> SearchTaskKey {
        SearchTaskKey(
            query: query.trimmingCharacters(in: .whitespacesAndNewlines),
            spaceScope: spaceScope,
            authorScope: authorScope,
            spaceID: spaceScope.resolvedSpaceID(currentSpaceID: provider.selectedSpaceID),
            creatorID: authorScope.resolvedCreatorID(currentUserID: provider.currentSearchUserID)
        )
    }

    func search(
        provider: any SearchProviding,
        reset: Bool = true,
        debounce: Duration = .zero
    ) async {
        guard Task.isCancelled == false else { return }
        let requestKey = taskKey(provider: provider)
        guard requestKey.query.count >= 2 else {
            invalidateSearch()
            return
        }
        guard reset || canLoadMore(for: requestKey) else { return }

        let requestedOffset = reset ? 0 : requestedResultCount
        if reset {
            invalidateSearch()
        }
        let requestID = UUID()
        activeRequestID = requestID
        isSearching = reset
        isLoadingMore = reset == false
        errorMessage = nil
        defer { finishRequest(requestID) }

        do {
            if debounce > .zero {
                try await Task.sleep(for: debounce)
            }
            try Task.checkCancellation()
            guard isCurrentRequest(requestID, key: requestKey, provider: provider) else { return }
            let fetchedResults = try await provider.search(
                query: requestKey.query,
                spaceId: requestKey.spaceID,
                creatorId: requestKey.creatorID,
                limit: Self.defaultPageSize,
                offset: requestedOffset
            )
            guard isCurrentRequest(requestID, key: requestKey, provider: provider) else { return }

            if reset {
                results = fetchedResults
            } else {
                appendUniqueResults(fetchedResults)
            }
            completedRequestKey = requestKey
            hasCompletedSearch = true
            requestedResultCount = requestedOffset + fetchedResults.count
            hasMoreResults = fetchedResults.count == Self.defaultPageSize
        } catch {
            guard isCurrentRequest(requestID, key: requestKey, provider: provider),
                  error is CancellationError == false else { return }
            errorMessage = error.localizedDescription
        }
    }

    func loadMore(provider: any SearchProviding) async {
        await search(provider: provider, reset: false)
    }

    private func finishRequest(_ id: UUID) {
        guard activeRequestID == id else { return }
        isSearching = false
        isLoadingMore = false
    }

    private func canLoadMore(for key: SearchTaskKey) -> Bool {
        hasMoreResults && isSearching == false && isLoadingMore == false && completedRequestKey == key
    }

    private func isCurrentRequest(
        _ id: UUID,
        key: SearchTaskKey,
        provider: any SearchProviding
    ) -> Bool {
        Task.isCancelled == false && activeRequestID == id && key == taskKey(provider: provider)
    }

    private func invalidateSearch() {
        activeRequestID = UUID()
        completedRequestKey = nil
        results = []
        errorMessage = nil
        hasMoreResults = false
        hasCompletedSearch = false
        requestedResultCount = 0
        isSearching = false
        isLoadingMore = false
    }

    private func appendUniqueResults(_ fetchedResults: [DocmostSearchResult]) {
        var seenIDs = Set(results.map(\.id))
        for result in fetchedResults where seenIDs.insert(result.id).inserted {
            results.append(result)
        }
    }
}

struct SearchTaskKey: Hashable {
    let query: String
    let spaceScope: SearchSpaceScope
    let authorScope: SearchAuthorScope
    let spaceID: String?
    let creatorID: String?
}
