import SwiftData
import SwiftUI

@main
struct DocmostlyApp: App {
    @State private var appState = AppState()

    private let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CachedSpace.self,
            CachedPageTreeItem.self,
            CachedPage.self,
            CachedAttachment.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create Docmostly model container: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
        .modelContainer(sharedModelContainer)
    }
}
