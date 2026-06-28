import SwiftUI
import SwiftData

@main
struct DocmostlyMacApp: App {
    @State private var appState = AppState.production()
    @State private var commandController = MacDesktopCommandController()
    private let sharedModelContainer = DocmostlyModelContainer.make()

    var body: some Scene {
        WindowGroup("Docmostly", id: "main") {
            MacRootView(modelContainer: sharedModelContainer)
                .environment(appState)
                .environment(commandController)
                .modelContainer(sharedModelContainer)
                .frame(minWidth: 980, minHeight: 680)
        }
        .windowToolbarStyle(.unified)
        .commands {
            DocmostlyMacCommands(
                appState: appState,
                commandController: commandController,
                modelContainer: sharedModelContainer
            )
        }

        WindowGroup("Page", for: MacPageWindowRoute.self) { route in
            if let route = route.wrappedValue {
                MacPageWindowView(route: route, modelContainer: sharedModelContainer)
                    .environment(appState)
                    .environment(commandController)
                    .modelContainer(sharedModelContainer)
            } else {
                ContentUnavailableView("No Page Selected", systemImage: "doc.text")
                    .environment(appState)
                    .environment(commandController)
                    .modelContainer(sharedModelContainer)
            }
        }
        .windowToolbarStyle(.unified)
        .defaultWindowPlacement { content, context in
            let idealSize = content.sizeThatFits(.unspecified)
            let visibleRect = context.defaultDisplay.visibleRect
            let size = CGSize(
                width: min(max(idealSize.width, 820), visibleRect.width * 0.9),
                height: min(max(idealSize.height, 680), visibleRect.height * 0.9)
            )
            return WindowPlacement(size: size)
        }
    }
}
