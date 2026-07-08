import SwiftUI

struct MainShellView: View {
    @Environment(AppState.self) private var appState
    #if os(macOS)
    @Environment(MacDesktopCommandController.self) private var commandController
    @State private var isShowingSpaceSettings = false
    #endif
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        #if os(macOS)
        NavigationSplitView(columnVisibility: $columnVisibility) {
            MacWorkspaceSidebarView()
        } detail: {
            MacMainShellDetailView()
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            await loadSpacesIfNeeded()
        }
        .task(id: commandController.spaceSettingsPresentationRequestID) {
            guard commandController.spaceSettingsPresentationRequestID != nil else { return }
            await loadSpacesIfNeeded()
            showSpaceSettings()
            commandController.clearSpaceSettingsPresentationRequest()
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
        .task {
            await loadSpacesIfNeeded()
        }
        #endif
    }

    private func loadSpacesIfNeeded() async {
        guard appState.spaces.isEmpty else { return }
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
