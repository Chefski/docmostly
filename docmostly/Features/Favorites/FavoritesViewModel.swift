import Foundation
import Observation

@MainActor
@Observable
final class FavoritesViewModel {
    var favorites: [DocmostFavorite] = []
    var isLoading = false
    var errorMessage: String?

    func load(appState: AppState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await appState.loadFavorites(limit: 50)
            favorites = response.items
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
