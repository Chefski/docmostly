import SwiftUI

struct MainShellView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    #if os(macOS)
    @Environment(MacDesktopCommandController.self) private var commandController
    @State private var isShowingSpaceSettings = false
    #endif
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var notificationStore = NotificationStore()

    var body: some View {
        Group {
            #if os(macOS)
            NavigationSplitView(columnVisibility: $columnVisibility) {
                MacWorkspaceSidebarView()
            } detail: {
                MacMainShellDetailView()
            }
            .navigationSplitViewStyle(.balanced)
            .task(id: commandController.spaceSettingsPresentationRequestID) {
                guard commandController.spaceSettingsPresentationRequestID != nil else { return }
                defer {
                    commandController.clearSpaceSettingsPresentationRequest()
                }
                guard await appState.loadSpaces() else { return }
                showSpaceSettings()
            }
            .sheet(isPresented: $isShowingSpaceSettings) {
                if let selectedSpace {
                    SpaceSettingsDialog(space: selectedSpace)
                } else {
                    ContentUnavailableView("No Space Selected", systemImage: "square.stack.3d.up")
                        .frame(minWidth: 480, minHeight: 280)
                }
            }
            #else
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarRootView()
            } content: {
                MainShellContentView()
            } detail: {
                MainShellDetailView()
            }
            .navigationSplitViewStyle(.balanced)
            .environment(
                \.pageOpenPresentation,
                horizontalSizeClass == .compact ? .stack : .detailColumn
            )
            #endif
        }
        .environment(notificationStore)
        .task {
            await loadSpacesIfNeeded()
        }
        .task {
            await notificationStore.pollUnreadCount(appState: appState)
        }
        .task {
            await notificationStore.monitorRealtime(appState: appState)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await notificationStore.refreshUnreadCount(appState: appState)
            }
        }
    }

    private func loadSpacesIfNeeded() async {
        await appState.loadSpaces()
    }

    #if os(macOS)
    private var selectedSpace: DocmostSpace? {
        if let selectedSpaceID = appState.selectedSpaceID,
           let space = appState.spaces.first(where: { $0.id == selectedSpaceID }) {
            return space
        }

        return appState.spaces.first
    }

    private func showSpaceSettings() {
        guard selectedSpace != nil else { return }
        isShowingSpaceSettings = true
    }
    #endif
}
