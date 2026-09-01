import SwiftUI

struct MainShellContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.pageOpenPresentation) private var pageOpenPresentation
    @State private var navigationPath = NavigationPath()

    var body: some View {
        Group {
            #if os(iOS)
            if pageOpenPresentation == .stack {
                NavigationStack(path: $navigationPath) {
                    MainShellContentRootView()
                }
            } else {
                MainShellContentRootView()
            }
            #else
            NavigationStack(path: $navigationPath) {
                MainShellContentRootView()
            }
            #endif
        }
        .onChange(of: appState.selectedSidebarDestination) {
            navigationPath = NavigationPath()
        }
        .navigationSplitViewColumnWidth(min: 280, ideal: 340, max: 460)
    }
}

private struct MainShellContentRootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.selectedSidebarDestination {
            case .favorites:
                FavoritesView()
            case .notifications:
                NotificationListView()
            case .search:
                SearchView()
            case .settings:
                SettingsView()
            case .space(let spaceID):
                if let space = appState.spaces.first(where: { $0.id == spaceID }) {
                    PageTreeView(space: space)
                } else {
                    ContentUnavailableView("Space unavailable", systemImage: "square.stack.3d.up")
                }
            case nil:
                ContentUnavailableView("Select a space", systemImage: "square.stack.3d.up")
            }
        }
    }
}
