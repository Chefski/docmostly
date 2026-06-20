import SwiftUI

struct SidebarRootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List {
            Section {
                NavigationLink(value: SidebarDestination.favorites) {
                    Label("Favorites", systemImage: "star")
                }
                NavigationLink(value: SidebarDestination.notifications) {
                    Label("Notifications", systemImage: "bell")
                }
                NavigationLink(value: SidebarDestination.search) {
                    Label("Search", systemImage: "magnifyingglass")
                }
                NavigationLink(value: SidebarDestination.settings) {
                    Label("Settings", systemImage: "gearshape")
                }
            }

            Section("Spaces") {
                ForEach(appState.spaces) { space in
                    NavigationLink(value: SidebarDestination.space(space.id)) {
                        SpaceRowView(space: space)
                    }
                    .listRowBackground(appState.selectedSpaceID == space.id ? DocmostlyTheme.primaryTint : nil)
                }

                if appState.spaces.isEmpty {
                    Text(appState.isOffline ? "No cached spaces" : "No spaces")
                        .foregroundStyle(.secondary)
                }
            }

            if appState.isOffline {
                OfflineBadgeView(text: "Offline")
                    .listRowSeparator(.hidden)
            }
        }
        .navigationTitle("Docmostly")
        .navigationDestination(for: SidebarDestination.self) { destination in
            switch destination {
            case .favorites:
                FavoritesView()
            case .notifications:
                NotificationListView()
            case .search:
                SearchView()
            case .settings:
                SettingsView()
            case .space(let spaceID):
                SpaceDestinationView(spaceID: spaceID)
            }
        }
        .refreshable {
            await appState.loadSpaces()
        }
    }
}
