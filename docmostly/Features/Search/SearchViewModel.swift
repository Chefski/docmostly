import Foundation
import Observation

@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    var results: [DocmostSearchResult] = []
    var isSearching = false
    var errorMessage: String?

    func search(appState: AppState) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            results = []
            return
        }

        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            results = try await appState.search(query: trimmed, spaceId: appState.selectedSpaceID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
