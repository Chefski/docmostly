import SwiftUI

struct MacRootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        RootView()
            .tint(.primary)
            .toolbar {
                if appState.phase == .authenticated {
                    ToolbarItemGroup {
                        Button("Refresh Spaces", systemImage: "arrow.clockwise", action: refreshSpaces)

                        Button("Search", systemImage: "magnifyingglass") {
                            appState.selectSidebarUtilityDestination(.search)
                        }
                    }
                }
            }
    }

    private func refreshSpaces() {
        Task {
            await appState.loadSpaces()
        }
    }
}
