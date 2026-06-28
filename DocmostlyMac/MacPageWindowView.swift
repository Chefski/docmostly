import SwiftData
import SwiftUI

struct MacPageWindowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    let route: MacPageWindowRoute
    let modelContainer: ModelContainer?

    init(route: MacPageWindowRoute, modelContainer: ModelContainer? = nil) {
        self.route = route
        self.modelContainer = modelContainer
    }

    var body: some View {
        NavigationStack {
            switch appState.phase {
            case .restoring:
                LoadingStateView(title: "Restoring session")
            case .needsServer, .unauthenticated:
                ContentUnavailableView(
                    "Sign In Required",
                    systemImage: "person.crop.circle.badge.exclamationmark",
                    description: Text("Open the main window to sign in.")
                )
            case .authenticated:
                PageReaderView(pageID: route.pageID, initialTitle: route.displayTitle)
            }
        }
        .frame(minWidth: 760, minHeight: 560)
        .task {
            appState.configure(modelContext: modelContext, modelContainer: modelContainer)
            await appState.restoreIfNeeded()
        }
        .focusedValue(\.macFocusedPageRoute, route)
    }
}
