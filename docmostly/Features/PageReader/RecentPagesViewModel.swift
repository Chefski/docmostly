import Foundation
import Observation

@MainActor
@Observable
final class RecentPagesViewModel {
    var pages: [DocmostPage] = []
    var isLoading = false
    var errorMessage: String?

    func load(appState: AppState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await appState.loadRecentPages(limit: 30)
            pages = response.items
        } catch {
            errorMessage = error.localizedDescription
            pages = appState.recentCachedPages(limit: 30).map { $0.asPage() }
        }
    }
}
