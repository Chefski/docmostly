import Foundation
import Observation

@MainActor
@Observable
final class PageBrowserViewModel {
    nonisolated static let defaultPageLimit = 50

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
        await load(
            spaceID: space.id,
            spaceNamesByID: [space.id: space.name],
            provider: provider,
            limit: limit
        )
    }

    func load(
        spaces: [DocmostSpace],
        provider: any PageBrowserProviding,
        limit: Int = PageBrowserViewModel.defaultPageLimit
    ) async {
        await load(
            spaceID: nil,
            spaceNamesByID: Dictionary(
                spaces.map { ($0.id, $0.name) },
                uniquingKeysWith: { existingName, _ in existingName }
            ),
            provider: provider,
            limit: limit
        )
    }

    private func load(
        spaceID: String?,
        spaceNamesByID: [String: String],
        provider: any PageBrowserProviding,
        limit: Int
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
                    spaceId: spaceID,
                    cursor: nil,
                    limit: limit
                )
                loadedItems = response.items.map {
                    PageBrowserItem(
                        page: $0,
                        fallbackSpaceName: spaceNamesByID[$0.spaceId] ?? "Unknown Space"
                    )
                }
            case .favorites:
                let response = try await provider.loadFavorites(
                    type: .page,
                    spaceId: spaceID,
                    cursor: nil,
                    limit: limit
                )
                loadedItems = response.items.compactMap {
                    PageBrowserItem(
                        favorite: $0,
                        fallbackSpaceName: $0.page.flatMap { spaceNamesByID[$0.spaceId] } ?? "Unknown Space"
                    )
                }
            case .createdByMe:
                let response = try await provider.loadCreatedByPages(
                    userId: provider.currentPageBrowserUserID,
                    spaceId: spaceID,
                    cursor: nil,
                    limit: limit
                )
                loadedItems = response.items.map {
                    PageBrowserItem(
                        page: $0,
                        fallbackSpaceName: spaceNamesByID[$0.spaceId] ?? "Unknown Space"
                    )
                }
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
