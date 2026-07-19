import Foundation
import Observation

@MainActor
@Observable
final class FavoritesViewModel {
    private static let pageSize = 30

    private var pages = CursorPageAccumulator<DocmostFavorite>()
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
        guard isLoading == false else { return }
        isLoading = true
        errorMessage = nil
        nextPageErrorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await appState.loadFavorites(limit: Self.pageSize)
            applyInitialPage(response)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadNextPage(appState: AppState) async {
        guard isLoading == false, isLoadingNextPage == false, let cursor = pages.nextCursor else { return }
        isLoadingNextPage = true
        nextPageErrorMessage = nil
        defer { isLoadingNextPage = false }

        do {
            let response = try await appState.loadFavorites(cursor: cursor, limit: Self.pageSize)
            applyNextPage(response, requestedCursor: cursor)
        } catch is CancellationError {
            return
        } catch {
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
        } catch is CancellationError {
            pages.restore(removal.item, at: removal.index)
        } catch {
            pages.restore(removal.item, at: removal.index)
            errorMessage = error.localizedDescription
        }
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
