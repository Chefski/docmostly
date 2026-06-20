import SwiftUI

struct MainShellView: View {
    @Environment(AppState.self) private var appState
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
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
    }
}
