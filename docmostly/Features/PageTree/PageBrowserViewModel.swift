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

    func load(space: DocmostSpace, provider: any PageBrowserProviding) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            switch selectedScope {
            case .recentlyUpdated:
                let response = try await provider.loadRecentPages(
                    spaceId: space.id,
                    cursor: nil,
                    limit: Self.defaultPageLimit
                )
                items = response.items.map { PageBrowserItem(page: $0, fallbackSpaceName: space.name) }
            case .favorites:
                let response = try await provider.loadFavorites(
                    type: .page,
                    spaceId: space.id,
                    cursor: nil,
                    limit: Self.defaultPageLimit
                )
                items = response.items.compactMap {
                    PageBrowserItem(favorite: $0, fallbackSpaceName: space.name)
                }
            case .createdByMe:
                let response = try await provider.loadCreatedByPages(
                    userId: provider.currentPageBrowserUserID,
                    spaceId: space.id,
                    cursor: nil,
                    limit: Self.defaultPageLimit
                )
                items = response.items.map { PageBrowserItem(page: $0, fallbackSpaceName: space.name) }
            }
        } catch {
            items = []
            errorMessage = error.localizedDescription
        }
    }
}
