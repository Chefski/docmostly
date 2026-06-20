import SwiftUI

#if os(macOS)
struct MacMainShellDetailView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        NavigationStack {
            if let selectedPageID = appState.selectedPageID {
                PageReaderView(pageID: selectedPageID)
            } else {
                MacMainShellEmptyPageDetailView()
            }
        }
        .navigationSplitViewColumnWidth(min: 520, ideal: 900)
    }
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
            if let selectedSpace {
                MacSpaceSettingsDetailView(space: selectedSpace)
                    .id(selectedSpace.id)
            } else {
                ContentUnavailableView("No Space Selected", systemImage: "square.stack.3d.up")
            }
        case .space, nil:
            RecentPagesView()
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

private struct MacSpaceSettingsDetailView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SettingsManagementViewModel()

    let space: DocmostSpace

    var body: some View {
        SpaceSettingsDetailView(space: space, canManage: canManage)
            .task {
                viewModel.seed(from: appState)
            }
    }

    private var canManage: Bool {
        viewModel.canManageWorkspace || space.membership?.role == "admin"
    }
}
#endif
