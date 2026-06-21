import SwiftData
import SwiftUI

@main
struct DocmostlyApp: App {
    @State private var appState = AppState.production()
    private let sharedModelContainer = DocmostlyModelContainer.make()

    var body: some Scene {
        WindowGroup {
            RootView(modelContainer: sharedModelContainer)
                .environment(appState)
        }
        .modelContainer(sharedModelContainer)
    }
}
