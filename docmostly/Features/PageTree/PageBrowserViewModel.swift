import Foundation
import Observation

@MainActor
@Observable
final class PageBrowserViewModel {
    static let defaultPageLimit = 50

    var selectedScope: PageBrowserScope = .recentlyUpdated
    private(set) var items: [PageBrowserItem] = []
    var isLoading = false
    var errorMessage: String?
    @ObservationIgnored private var activeLoadID = UUID()

    func load(
        space: DocmostSpace,
        provider: any PageBrowserProviding,
        limit: Int = PageBrowserViewModel.defaultPageLimit
    ) async {
        let requestedScope = selectedScope
        let loadID = UUID()
        activeLoadID = loadID
        isLoading = true
        errorMessage = nil
        defer {
            if activeLoadID == loadID {
                isLoading = false
            }
        }

        do {
            let loadedItems: [PageBrowserItem]
            switch requestedScope {
            case .recentlyUpdated:
                let response = try await provider.loadRecentPages(
                    spaceId: space.id,
                    cursor: nil,
                    limit: limit
                )
                loadedItems = response.items.map { PageBrowserItem(page: $0, fallbackSpaceName: space.name) }
            case .favorites:
                let response = try await provider.loadFavorites(
                    type: .page,
                    spaceId: space.id,
                    cursor: nil,
                    limit: limit
                )
                loadedItems = response.items.compactMap {
                    PageBrowserItem(favorite: $0, fallbackSpaceName: space.name)
                }
            case .createdByMe:
                let response = try await provider.loadCreatedByPages(
                    userId: provider.currentPageBrowserUserID,
                    spaceId: space.id,
                    cursor: nil,
                    limit: limit
                )
                loadedItems = response.items.map { PageBrowserItem(page: $0, fallbackSpaceName: space.name) }
            }

            guard activeLoadID == loadID, selectedScope == requestedScope, Task.isCancelled == false else { return }
            items = loadedItems
        } catch {
            guard activeLoadID == loadID, selectedScope == requestedScope, Task.isCancelled == false else { return }
            items = []
            errorMessage = error.localizedDescription
        }
    }
}
