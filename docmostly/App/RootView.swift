import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    let modelContainer: ModelContainer?

    init(modelContainer: ModelContainer? = nil) {
        self.modelContainer = modelContainer
    }

    var body: some View {
        Group {
            #if DEBUG
            if CommandLine.arguments.contains("-NativeEditorPreview") {
                NativeEditorDebugPreviewView()
            } else if CommandLine.arguments.contains("-MainShellPreview") {
                MainShellDebugPreviewView(modelContainer: modelContainer)
            } else {
                appContent
            }
            #else
            appContent
            #endif
        }
        .task {
            #if DEBUG
            guard CommandLine.arguments.contains("-NativeEditorPreview") == false else { return }
            guard CommandLine.arguments.contains("-MainShellPreview") == false else { return }
            #endif
            appState.configure(modelContext: modelContext, modelContainer: modelContainer)
            await appState.restore()
        }
    }

    private var appContent: some View {
        Group {
            switch appState.phase {
            case .restoring:
                LoadingStateView(title: "Restoring session")
            case .needsServer:
                LoginView()
            case .unauthenticated:
                LoginView()
            case .authenticated:
                MainShellView()
            }
        }
    }
}
