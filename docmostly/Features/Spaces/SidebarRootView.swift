import SwiftUI

struct SidebarRootView: View {
    @Environment(AppState.self) private var appState
    @Environment(NotificationStore.self) private var notificationStore
    @State private var pageBrowserViewModel = PageBrowserViewModel()

    var body: some View {
        List(selection: sidebarSelection) {
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

            SidebarPageBrowserSection(viewModel: pageBrowserViewModel)

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
            _ = await appState.loadSpaces()
            await loadPageBrowser()
        }
        .task(id: pageBrowserTaskKey) {
            await loadPageBrowser()
        }
        .pageOpenDestination()
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
        "Syncline"
        #endif
    }

    private var pageBrowserTaskKey: SidebarPageBrowserTaskKey {
        SidebarPageBrowserTaskKey(
            spaceIDs: appState.spaces.map(\.id),
            scope: pageBrowserViewModel.selectedScope,
            pageDiscoveryRevision: appState.pageDiscoveryRevision,
            favoriteRevision: appState.favoriteRevision
        )
    }

    private func loadPageBrowser() async {
        await pageBrowserViewModel.load(spaces: appState.spaces, provider: appState)
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        #if os(iOS)
        ToolbarItem(placement: .topBarLeading) {
            WorkspaceAccountMenu()
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button("Favorites", systemImage: "star") {
                appState.selectSidebarUtilityDestination(.favorites)
            }

            Button(
                "Notifications",
                systemImage: notificationStore.unreadCount > 0 ? "bell.badge" : "bell"
            ) {
                appState.selectSidebarUtilityDestination(.notifications)
            }
            .accessibilityValue(notificationAccessibilityValue)
        }
        #else
        ToolbarItem(placement: .primaryAction) {
            WorkspaceAccountMenu()
        }
        #endif
    }

    private var notificationAccessibilityValue: String {
        if notificationStore.unreadCount == 0 {
            return "No unread notifications"
        }

        return "\(notificationStore.unreadCount) unread"
    }
}

private struct SidebarPageBrowserTaskKey: Hashable {
    let spaceIDs: [String]
    let scope: PageBrowserScope
    let pageDiscoveryRevision: Int
    let favoriteRevision: Int
}
