import SwiftUI
import SwiftData

struct MacRootView: View {
    @Environment(AppState.self) private var appState

    let modelContainer: ModelContainer?

    init(modelContainer: ModelContainer? = nil) {
        self.modelContainer = modelContainer
    }

    var body: some View {
        RootView(modelContainer: modelContainer)
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
