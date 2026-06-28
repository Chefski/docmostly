import SwiftData
import SwiftUI

struct MacPageWindowView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    @Environment(MacDesktopCommandController.self) private var commandController
    @State private var isCommandPalettePresented = false
    @State private var isPageCreationPresented = false

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
        .sheet(isPresented: $isCommandPalettePresented) {
            MacCommandPaletteView(
                items: commandPaletteItems,
                openSearchResult: openSearchResult,
                openSearchResultInNewWindow: openSearchResultInNewWindow
            )
            .environment(appState)
        }
        .sheet(isPresented: $isPageCreationPresented) {
            MacQuickPageCreationSheet(
                selectedSpace: selectedSpace,
                createRootPage: createRootPage
            )
        }
        .task {
            appState.configure(modelContext: modelContext, modelContainer: modelContainer)
            await appState.restoreIfNeeded()
        }
        .focusedValue(\.macDesktopCommandActions, focusedCommandActions)
        .focusedValue(\.macFocusedPageRoute, route)
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
                presentPageCreation()
            },
            MacCommandPaletteItem(
                title: "Open Current Page in New Window",
                subtitle: route.displayTitle,
                systemImage: "macwindow.on.rectangle",
                keywords: ["separate", "desktop"]
            ) {
                openSelectedPageInNewWindow()
            },
            MacCommandPaletteItem(
                title: "Search Workspace",
                subtitle: selectedSpace.map { $0.name },
                systemImage: "magnifyingglass",
                keywords: ["find", "pages"]
            ) {
                selectSidebarDestination(.search)
            },
            MacCommandPaletteItem(
                title: "Favorites",
                subtitle: nil,
                systemImage: "star",
                keywords: ["starred"],
                isEnabled: appState.phase == .authenticated
            ) {
                selectSidebarDestination(.favorites)
            },
            MacCommandPaletteItem(
                title: "Notifications",
                subtitle: nil,
                systemImage: "bell",
                keywords: ["inbox", "updates"],
                isEnabled: appState.phase == .authenticated
            ) {
                selectSidebarDestination(.notifications)
            },
            MacCommandPaletteItem(
                title: "Space Settings",
                subtitle: selectedSpace?.name,
                systemImage: "gearshape",
                keywords: ["permissions", "members"],
                isEnabled: appState.phase == .authenticated
            ) {
                selectSidebarDestination(.settings)
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
        if let spaceID = route.spaceID,
           let space = appState.spaces.first(where: { $0.id == spaceID }) {
            return space
        }

        if let selectedSpaceID = appState.selectedSpaceID,
           let space = appState.spaces.first(where: { $0.id == selectedSpaceID }) {
            return space
        }

        return appState.spaces.first
    }

    private var canCreatePage: Bool {
        appState.phase == .authenticated && appState.isOffline == false && selectedSpace != nil
    }

    private var focusedCommandActions: MacDesktopCommandActions {
        MacDesktopCommandActions(
            canCreatePage: { canCreatePage },
            selectedPageRoute: { route },
            presentCommandPalette: presentCommandPalette,
            presentPageCreation: presentPageCreation,
            selectSidebarDestination: selectSidebarDestination,
            openSelectedPageInNewWindow: openSelectedPageInNewWindow
        )
    }

    private func presentCommandPalette() {
        isCommandPalettePresented = true
    }

    private func presentPageCreation() {
        isPageCreationPresented = true
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
            commandController.requestSidebarReload()
            openWindow(value: MacPageWindowRoute(
                pageID: page.slugId,
                spaceID: page.spaceId,
                title: page.title
            ))
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    private func openSearchResult(_ result: DocmostSearchResult) {
        appState.selectPage(id: result.slugId, spaceID: result.space.id, revealSpaceInSidebar: true)
        openWindow(id: "main")
    }

    private func openSearchResultInNewWindow(_ result: DocmostSearchResult) {
        openWindow(value: MacPageWindowRoute(
            pageID: result.slugId,
            spaceID: result.space.id,
            title: result.title
        ))
    }

    private func openSelectedPageInNewWindow() {
        openWindow(value: route)
    }

    private func selectSidebarDestination(_ destination: SidebarDestination) {
        appState.selectSidebarUtilityDestination(destination)
        openWindow(id: "main")
    }

    private func showSettings() {
        guard let modelContainer else { return }

        MacSettingsWindowController.show(
            appState: appState,
            modelContainer: modelContainer
        )
    }
}
