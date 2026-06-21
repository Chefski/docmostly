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
        guard trimmed.count >= 2 else {
            results = []
            errorMessage = nil
            return
        }

        isSearching = true
        errorMessage = nil
        defer { isSearching = false }

        do {
            let fetchedResults = try await appState.search(query: trimmed, spaceId: appState.selectedSpaceID)
            guard Task.isCancelled == false else { return }
            guard trimmed == query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            results = fetchedResults
        } catch {
            guard Task.isCancelled == false else { return }
            errorMessage = error.localizedDescription
        }
    }
}
