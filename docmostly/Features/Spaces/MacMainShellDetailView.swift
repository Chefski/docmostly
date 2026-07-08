import SwiftUI

#if os(macOS)
struct MacMainShellDetailView: View {
    @Environment(AppState.self) private var appState
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            if let selectedPageID = appState.selectedPageID {
                PageReaderView(pageID: selectedPageID)
            } else {
                MacMainShellEmptyPageDetailView()
            }
        }
        .navigationSplitViewColumnWidth(min: 520, ideal: 900)
        .onChange(of: navigationResetKey) { _, _ in
            navigationPath = NavigationPath()
        }
    }

    private var navigationResetKey: MacMainShellDetailNavigationResetKey {
        MacMainShellDetailNavigationResetKey(
            destination: appState.selectedSidebarDestination,
            selectedSpaceID: appState.selectedSpaceID,
            selectedPageID: appState.selectedPageID
        )
    }
}

private struct MacMainShellDetailNavigationResetKey: Equatable {
    let destination: SidebarDestination?
    let selectedSpaceID: String?
    let selectedPageID: String?
}

private struct MacMainShellEmptyPageDetailView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        switch appState.selectedSidebarDestination {
        case .favorites:
            FavoritesView()
        case .notifications:
            NotificationListView()
        case .search:
            SearchView()
        case .settings:
            SettingsView()
        case .space, nil:
            if let selectedSpace {
                PageBrowserHomeView(space: selectedSpace)
                    .id(selectedSpace.id)
            } else {
                ContentUnavailableView("No Space Selected", systemImage: "square.stack.3d.up")
            }
        }
    }

    private var selectedSpace: DocmostSpace? {
        if let selectedSpaceID = appState.selectedSpaceID,
           let space = appState.spaces.first(where: { $0.id == selectedSpaceID }) {
            return space
        }

        return appState.spaces.first
    }
}
#endif
