import SwiftData
import SwiftUI

@MainActor
struct DocmostlyMacCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    let appState: AppState
    let commandController: MacDesktopCommandController
    let modelContainer: ModelContainer

    var body: some Commands {
        SidebarCommands()

        CommandGroup(replacing: .newItem) {
            Button("New Page", systemImage: "doc.badge.plus", action: presentPageCreation)
                .keyboardShortcut("n", modifiers: .command)
                .disabled(canCreatePage == false)

            Button("New Window", systemImage: "macwindow") {
                openWindow(id: "main")
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
        }

        CommandGroup(replacing: .appSettings) {
            Button("Settings...", systemImage: "gearshape", action: showSettings)
                .keyboardShortcut(",", modifiers: .command)
        }

        CommandMenu("Navigate") {
            Button("Command Palette", systemImage: "command", action: presentCommandPalette)
                .keyboardShortcut("k", modifiers: .command)

            Divider()

            Button("Favorites", systemImage: "star") {
                select(.favorites)
            }
            .keyboardShortcut("1", modifiers: .command)
            .disabled(appState.phase != .authenticated)

            Button("Notifications", systemImage: "bell") {
                select(.notifications)
            }
            .keyboardShortcut("2", modifiers: .command)
            .disabled(appState.phase != .authenticated)

            Button("Search Workspace", systemImage: "magnifyingglass") {
                select(.search)
            }
            .keyboardShortcut("3", modifiers: .command)
            .disabled(appState.phase != .authenticated)

            Button("Space Settings", systemImage: "gearshape") {
                select(.settings)
            }
            .keyboardShortcut("4", modifiers: .command)
            .disabled(appState.phase != .authenticated)
        }

        CommandMenu("Page") {
            Button(
                "Open Page in New Window",
                systemImage: "macwindow.on.rectangle",
                action: openSelectedPageInNewWindow
            )
                .keyboardShortcut("o", modifiers: [.command, .option])
                .disabled(selectedPageRoute == nil)
        }

        CommandMenu("Workspace") {
            Button("Refresh Spaces", systemImage: "arrow.clockwise", action: refreshSpaces)
                .keyboardShortcut("r", modifiers: .command)
                .disabled(appState.phase != .authenticated)
        }
    }

    private var canCreatePage: Bool {
        appState.phase == .authenticated && appState.isOffline == false && selectedSpace != nil
    }

    private var selectedPageRoute: MacPageWindowRoute? {
        MacPageWindowRoute.selectedPageRoute(from: appState)
    }

    private var selectedSpace: DocmostSpace? {
        if let selectedSpaceID = appState.selectedSpaceID,
           let space = appState.spaces.first(where: { $0.id == selectedSpaceID }) {
            return space
        }

        return appState.spaces.first
    }

    private func presentCommandPalette() {
        openWindow(id: "main")
        Task { @MainActor in
            await Task.yield()
            commandController.presentCommandPalette()
        }
    }

    private func presentPageCreation() {
        openWindow(id: "main")
        Task { @MainActor in
            await Task.yield()
            commandController.presentPageCreation()
        }
    }

    private func showSettings() {
        MacSettingsWindowController.show(
            appState: appState,
            modelContainer: modelContainer
        )
    }

    private func refreshSpaces() {
        Task {
            await appState.loadSpaces()
            commandController.requestSidebarReload()
        }
    }

    private func select(_ destination: SidebarDestination) {
        appState.selectSidebarUtilityDestination(destination)
        openWindow(id: "main")
    }

    private func openSelectedPageInNewWindow() {
        guard let selectedPageRoute else { return }
        openWindow(value: selectedPageRoute)
    }
}
