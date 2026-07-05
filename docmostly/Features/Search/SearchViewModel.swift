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

    var query = ""
    var results: [DocmostSearchResult] = []
    var isSearching = false
    var isLoadingMore = false
    var hasMoreResults = false
    var errorMessage: String?
    var spaceScope: SearchSpaceScope = .currentSpace
    var authorScope: SearchAuthorScope = .anyone
    private var requestedResultCount = 0

    var searchTaskKey: SearchTaskKey {
        SearchTaskKey(query: query, spaceScope: spaceScope, authorScope: authorScope)
    }

    func search(provider: any SearchProviding, reset: Bool = true) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            errorMessage = nil
            hasMoreResults = false
            requestedResultCount = 0
            return
        }

        let requestedSpaceScope = spaceScope
        let requestedAuthorScope = authorScope
        let requestedOffset = reset ? 0 : requestedResultCount
        let requestedSpaceID = requestedSpaceScope.resolvedSpaceID(currentSpaceID: provider.selectedSpaceID)
        let requestedCreatorID = requestedAuthorScope.resolvedCreatorID(currentUserID: provider.currentSearchUserID)

        if reset {
            isSearching = true
        } else {
            isLoadingMore = true
        }
        errorMessage = nil
        defer {
            if reset {
                isSearching = false
            } else {
                isLoadingMore = false
            }
        }

        do {
            let fetchedResults = try await provider.search(
                query: trimmed,
                spaceId: requestedSpaceID,
                creatorId: requestedCreatorID,
                limit: Self.defaultPageSize,
                offset: requestedOffset
            )
            guard Task.isCancelled == false else { return }
            guard isCurrentRequest(
                query: trimmed,
                spaceScope: requestedSpaceScope,
                authorScope: requestedAuthorScope
            ) else { return }

            if reset {
                results = fetchedResults
            } else {
                appendUniqueResults(fetchedResults)
            }
            requestedResultCount = requestedOffset + fetchedResults.count
            hasMoreResults = fetchedResults.count == Self.defaultPageSize
        } catch {
            guard Task.isCancelled == false else { return }
            errorMessage = error.localizedDescription
        }
    }

    func loadMore(provider: any SearchProviding) async {
        guard hasMoreResults, isSearching == false, isLoadingMore == false else { return }
        await search(provider: provider, reset: false)
    }

    private func isCurrentRequest(
        query requestedQuery: String,
        spaceScope requestedSpaceScope: SearchSpaceScope,
        authorScope requestedAuthorScope: SearchAuthorScope
    ) -> Bool {
        requestedQuery == query.trimmingCharacters(in: .whitespacesAndNewlines) &&
            requestedSpaceScope == spaceScope &&
            requestedAuthorScope == authorScope
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
}
