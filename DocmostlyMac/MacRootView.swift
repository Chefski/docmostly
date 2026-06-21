import SwiftUI

struct MacRootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        RootView()
            .tint(.primary)
            .toolbar {
                if appState.phase == .authenticated {
                    ToolbarItemGroup {
                        Button("Search", systemImage: "magnifyingglass") {
                            appState.selectSidebarUtilityDestination(.search)
                        }
                    }
                }
            }
    }
}
