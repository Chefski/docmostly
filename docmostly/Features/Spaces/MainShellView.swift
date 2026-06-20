import SwiftUI

struct MainShellView: View {
    @Environment(AppState.self) private var appState
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
            await appState.loadSpaces()
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
            await appState.loadSpaces()
        }
        #endif
    }
}
