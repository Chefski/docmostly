import SwiftUI
import SwiftData
import Observation

struct MacRootView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(AppState.self) private var appState
    @Environment(MacDesktopCommandController.self) private var commandController

    let modelContainer: ModelContainer?

    init(modelContainer: ModelContainer? = nil) {
        self.modelContainer = modelContainer
    }

    var body: some View {
        @Bindable var commandController = commandController

        RootView(modelContainer: modelContainer)
            .tint(.primary)
            .toolbar {
                if appState.phase == .authenticated {
                    ToolbarItemGroup {
                        Button("New Page", systemImage: "doc.badge.plus") {
                            commandController.presentPageCreation()
                        }
                        .disabled(canCreatePage == false)

                        Button("Command Palette", systemImage: "command") {
                            commandController.presentCommandPalette()
                        }

                        Button("Search", systemImage: "magnifyingglass") {
                            appState.selectSidebarUtilityDestination(.search)
                        }
                    }
                }
            }
            .sheet(isPresented: $commandController.isCommandPalettePresented) {
                MacCommandPaletteView(
                    items: commandPaletteItems,
                    openSearchResult: openSearchResult,
                    openSearchResultInNewWindow: openSearchResultInNewWindow
                )
                .environment(appState)
            }
            .sheet(isPresented: $commandController.isPageCreationPresented) {
                quickPageCreationSheet
            }
    }

    @ViewBuilder
    private var quickPageCreationSheet: some View {
        if let selectedSpace {
            PageCreationSheet(
                request: PageCreationRequest(parent: nil, spaceName: selectedSpace.name),
                create: createRootPage
            )
            .frame(minWidth: 420, minHeight: 260)
        } else {
            ContentUnavailableView("No Space Selected", systemImage: "square.stack.3d.up")
                .frame(minWidth: 420, minHeight: 260)
        }
    }

    private var commandPaletteItems: [MacCommandPaletteItem] {
        [
            MacCommandPaletteItem(
                title: "New Page",
                subtitle: selectedSpace.map { "Create in \($0.name)" },
                systemImage: "doc.badge.plus",
                keywords: ["create", "quick"],
                isEnabled: canCreatePage
            ) {
                commandController.presentPageCreation()
            },
            MacCommandPaletteItem(
                title: "Open Current Page in New Window",
                subtitle: nil,
                systemImage: "macwindow.on.rectangle",
                keywords: ["separate", "desktop"],
                isEnabled: selectedPageRoute != nil
            ) {
                openSelectedPageInNewWindow()
            },
            MacCommandPaletteItem(
                title: "Search Workspace",
                subtitle: selectedSpace.map { $0.name },
                systemImage: "magnifyingglass",
                keywords: ["find", "pages"]
            ) {
                appState.selectSidebarUtilityDestination(.search)
            },
            MacCommandPaletteItem(
                title: "Favorites",
                subtitle: nil,
                systemImage: "star",
                keywords: ["starred"],
                isEnabled: appState.phase == .authenticated
            ) {
                appState.selectSidebarUtilityDestination(.favorites)
            },
            MacCommandPaletteItem(
                title: "Notifications",
                subtitle: nil,
                systemImage: "bell",
                keywords: ["inbox", "updates"],
                isEnabled: appState.phase == .authenticated
            ) {
                appState.selectSidebarUtilityDestination(.notifications)
            },
            MacCommandPaletteItem(
                title: "Space Settings",
                subtitle: selectedSpace?.name,
                systemImage: "gearshape",
                keywords: ["permissions", "members"],
                isEnabled: appState.phase == .authenticated
            ) {
                appState.selectSidebarUtilityDestination(.settings)
            },
            MacCommandPaletteItem(
                title: "Refresh Spaces",
                subtitle: nil,
                systemImage: "arrow.clockwise",
                keywords: ["reload", "sync"],
                isEnabled: appState.phase == .authenticated
            ) {
                Task {
                    await appState.loadSpaces()
                    commandController.requestSidebarReload()
                }
            },
            MacCommandPaletteItem(
                title: "Settings",
                subtitle: nil,
                systemImage: "gearshape",
                keywords: ["preferences"],
                isEnabled: modelContainer != nil
            ) {
                showSettings()
            }
        ]
    }

    private var selectedSpace: DocmostSpace? {
        if let selectedSpaceID = appState.selectedSpaceID,
           let space = appState.spaces.first(where: { $0.id == selectedSpaceID }) {
            return space
        }

        return appState.spaces.first
    }

    private var canCreatePage: Bool {
        appState.phase == .authenticated && appState.isOffline == false && selectedSpace != nil
    }

    private var selectedPageRoute: MacPageWindowRoute? {
        MacPageWindowRoute.selectedPageRoute(from: appState)
    }

    private func createRootPage(title: String) async -> String? {
        guard let selectedSpace else {
            return "No space selected."
        }

        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        do {
            let page = try await appState.createPage(
                spaceId: selectedSpace.id,
                title: trimmedTitle.isEmpty ? nil : trimmedTitle
            )
            appState.selectPage(id: page.slugId, spaceID: page.spaceId, revealSpaceInSidebar: true)
            commandController.requestSidebarReload()
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func openSearchResult(_ result: DocmostSearchResult) {
        openWindow(id: "main")
        appState.selectPage(id: result.slugId, spaceID: result.space.id, revealSpaceInSidebar: true)
    }

    private func openSearchResultInNewWindow(_ result: DocmostSearchResult) {
        openWindow(value: MacPageWindowRoute(
            pageID: result.slugId,
            spaceID: result.space.id,
            title: result.title
        ))
    }

    private func openSelectedPageInNewWindow() {
        guard let selectedPageRoute else { return }
        openWindow(value: selectedPageRoute)
    }

    private func showSettings() {
        guard let modelContainer else { return }

        MacSettingsWindowController.show(
            appState: appState,
            modelContainer: modelContainer
        )
    }
}
