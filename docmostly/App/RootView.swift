import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    var body: some View {
        Group {
            switch appState.phase {
            case .restoring:
                LoadingStateView(title: "Restoring session")
            case .needsServer:
                ServerSetupView()
            case .unauthenticated:
                LoginView()
            case .authenticated:
                MainShellView()
            }
        }
        .task {
            appState.configure(modelContext: modelContext)
            await appState.restore()
        }
    }
}
