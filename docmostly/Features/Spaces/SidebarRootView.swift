import SwiftUI

struct SidebarRootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        List(selection: sidebarSelection) {
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
        .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        .refreshable {
            await appState.loadSpaces()
        }
    }

    private var sidebarSelection: Binding<SidebarDestination?> {
        Binding {
            appState.selectedSidebarDestination
        } set: { destination in
            appState.selectSidebarDestination(destination)
        }
    }
}
