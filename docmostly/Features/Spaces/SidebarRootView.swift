import SwiftUI

struct SidebarRootView: View {
    @Environment(AppState.self) private var appState
    @Environment(NotificationStore.self) private var notificationStore

    var body: some View {
        List(selection: sidebarSelection) {
            Section {
                NavigationLink(value: SidebarDestination.favorites) {
                    Label("Favorites", systemImage: "star")
                }
                NavigationLink(value: SidebarDestination.notifications) {
                    HStack {
                        Label("Notifications", systemImage: "bell")
                        Spacer(minLength: 0)
                        if notificationStore.unreadCount > 0 {
                            Text(notificationStore.unreadCount > 99 ? "99+" : notificationStore.unreadCount.formatted())
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("\(notificationStore.unreadCount) unread")
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
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
        .navigationTitle(navigationTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar(content: toolbarContent)
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

    private var navigationTitle: String {
        #if os(iOS)
        ""
        #else
        "Docmostly"
        #endif
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .topBarLeading) {
            WorkspaceAccountMenu()
        }
        #else
        ToolbarItem(placement: .primaryAction) {
            WorkspaceAccountMenu()
        }
        #endif
    }
}
