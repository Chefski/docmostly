import Foundation
import Observation

@MainActor
@Observable
final class FavoritesViewModel {
    private static let pageSize = 30

    private var pages = CursorPageAccumulator<DocmostFavorite>()
    @ObservationIgnored private var loadRequestID: UUID?
    @ObservationIgnored private var paginationGeneration: UInt = 0
    var isLoading = false
    var isLoadingNextPage = false
    var mutatingFavoriteIDs: Set<String> = []
    var errorMessage: String?
    var nextPageErrorMessage: String?

    var favorites: [DocmostFavorite] {
        pages.items
    }

    var hasNextPage: Bool {
        pages.hasNextPage
    }

    var sections: [FavoriteSectionGroup] {
        FavoriteType.displayOrder.compactMap { type in
            var sectionFavorites = favorites.filter { $0.type == type }
            if type == .space {
                sectionFavorites.sort { lhs, rhs in
                    lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
                }
            }
            guard sectionFavorites.isEmpty == false else { return nil }
            return FavoriteSectionGroup(type: type, favorites: sectionFavorites)
        }
    }

    func load(appState: AppState) async {
        await load {
            try await appState.loadFavorites(limit: Self.pageSize)
        }
    }

    func load(
        operation: () async throws -> PaginatedResponse<DocmostFavorite>
    ) async {
        let requestID = UUID()
        paginationGeneration &+= 1
        isLoadingNextPage = false
        loadRequestID = requestID
        isLoading = true
        errorMessage = nil
        nextPageErrorMessage = nil
        defer {
            if loadRequestID == requestID {
                isLoading = false
            }
        }

        do {
            let response = try await operation()
            guard loadRequestID == requestID, Task.isCancelled == false else { return }
            applyInitialPage(response)
        } catch {
            guard loadRequestID == requestID, Task.isCancelled == false else { return }
            guard Self.isCancelledLoadError(error) == false else { return }
            errorMessage = error.localizedDescription
        }
    }

    func loadNextPage(appState: AppState) async {
        await loadNextPage {
            try await appState.loadFavorites(cursor: $0, limit: Self.pageSize)
        }
    }

    func loadNextPage(
        operation: (String) async throws -> PaginatedResponse<DocmostFavorite>
    ) async {
        guard isLoading == false, isLoadingNextPage == false, let cursor = pages.nextCursor else { return }
        let generation = paginationGeneration
        isLoadingNextPage = true
        nextPageErrorMessage = nil
        defer {
            if paginationGeneration == generation {
                isLoadingNextPage = false
            }
        }

        do {
            let response = try await operation(cursor)
            guard paginationGeneration == generation, Task.isCancelled == false else { return }
            applyNextPage(response, requestedCursor: cursor)
        } catch {
            guard paginationGeneration == generation, Task.isCancelled == false else { return }
            guard Self.isCancelledLoadError(error) == false else { return }
            nextPageErrorMessage = error.localizedDescription
        }
    }

    func remove(_ favorite: DocmostFavorite, appState: AppState) async {
        await remove(favorite) {
            try await appState.removeFavorite(
                type: favorite.type,
                pageId: favorite.pageId,
                spaceId: favorite.spaceId,
                templateId: favorite.templateId
            )
        }
    }

    func applyInitialPage(_ response: PaginatedResponse<DocmostFavorite>) {
        pages.replace(with: response)
    }

    func applyNextPage(
        _ response: PaginatedResponse<DocmostFavorite>,
        requestedCursor: String
    ) {
        pages.append(response, requestedCursor: requestedCursor)
    }

    func remove(
        _ favorite: DocmostFavorite,
        operation: () async throws -> Void
    ) async {
        guard mutatingFavoriteIDs.insert(favorite.id).inserted else { return }
        guard let removal = pages.remove(id: favorite.id) else {
            mutatingFavoriteIDs.remove(favorite.id)
            return
        }

        errorMessage = nil
        defer { mutatingFavoriteIDs.remove(favorite.id) }

        do {
            try await operation()
        } catch {
            pages.restore(removal.item, at: removal.index)
            guard Self.isCancelledLoadError(error) == false else { return }
            errorMessage = error.localizedDescription
        }
    }

    static func isCancelledLoadError(_ error: any Error) -> Bool {
        if error is CancellationError {
            return true
        }

        let nsError = error as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}

nonisolated struct FavoriteSectionGroup: Identifiable, Sendable {
    let type: FavoriteType
    let favorites: [DocmostFavorite]

    var id: FavoriteType { type }
}

nonisolated extension FavoriteType {
    static let displayOrder: [FavoriteType] = [.space, .page, .template]

    var sectionTitle: String {
        switch self {
        case .space:
            "Favorite Spaces"
        case .page:
            "Favorite Pages"
        case .template:
            "Favorite Templates"
        }
    }
}
