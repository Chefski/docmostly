import SwiftUI
import SwiftData

@main
struct DocmostlyMacApp: App {
    @State private var appState = AppState.production()
    private let sharedModelContainer = DocmostlyModelContainer.make()

    var body: some Scene {
        WindowGroup("Docmostly", id: "main") {
            MacRootView()
                .environment(appState)
                .modelContainer(sharedModelContainer)
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowToolbarStyle(.unified)
        .commands {
            SidebarCommands()

            CommandMenu("Docmostly") {
                Button("Refresh Spaces", systemImage: "arrow.clockwise", action: refreshSpaces)
                    .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Favorites", systemImage: "star") {
                    select(.favorites)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Notifications", systemImage: "bell") {
                    select(.notifications)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Search", systemImage: "magnifyingglass") {
                    select(.search)
                }
                .keyboardShortcut("f", modifiers: .command)
            }
        }

        Settings {
            MacSettingsView()
                .environment(appState)
                .modelContainer(sharedModelContainer)
        }
    }

    private func refreshSpaces() {
        Task {
            await appState.loadSpaces()
        }
    }

    private func select(_ destination: SidebarDestination) {
        appState.selectSidebarUtilityDestination(destination)
    }
}
