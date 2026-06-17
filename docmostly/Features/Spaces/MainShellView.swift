import SwiftUI

struct MainShellView: View {
    @Environment(AppState.self) private var appState
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarRootView()
        } content: {
            if let selectedSpace {
                PageTreeView(space: selectedSpace)
            } else {
                ContentUnavailableView("Select a space", systemImage: "square.stack.3d.up")
            }
        } detail: {
            if let selectedPageID = appState.selectedPageID {
                PageReaderView(pageID: selectedPageID)
            } else {
                RecentPagesView()
            }
        }
        .task {
            await appState.loadSpaces()
        }
    }

    private var selectedSpace: DocmostSpace? {
        appState.spaces.first { $0.id == appState.selectedSpaceID }
    }
}
