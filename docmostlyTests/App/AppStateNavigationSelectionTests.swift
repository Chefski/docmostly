import Foundation
import Testing
@testable import docmostly

@MainActor
struct AppStateNavigationSelectionTests {
    @Test func selectingASpaceActivatesTheSpaceColumnAndClearsTheCurrentPage() {
        let appState = makeAppState()
        appState.selectedPageID = "page-1"

        appState.selectSpace(id: "space-1")

        #expect(appState.selectedSidebarDestination == .space("space-1"))
        #expect(appState.selectedSpaceID == "space-1")
        #expect(appState.selectedPageID == nil)
    }

    @Test func selectingASidebarSpaceClearsTheCurrentPage() {
        let appState = makeAppState()
        appState.selectSidebarDestination(.search)
        appState.selectPage(id: "page-1", spaceID: "space-1")

        appState.selectSidebarDestination(.space("space-2"))

        #expect(appState.selectedSidebarDestination == .space("space-2"))
        #expect(appState.selectedSpaceID == "space-2")
        #expect(appState.selectedPageID == nil)
    }

    @Test func openingAPageFromAuxiliaryListsKeepsTheCurrentSidebarListVisible() {
        let appState = makeAppState()
        appState.selectSidebarDestination(.search)

        appState.selectPage(id: "page-1", spaceID: "space-1", revealSpaceInSidebar: false)

        #expect(appState.selectedSidebarDestination == .search)
        #expect(appState.selectedSpaceID == "space-1")
        #expect(appState.selectedPageID == "page-1")
    }

    @Test func openingAPageFromThePageTreeCanRevealItsSpaceInTheSidebar() {
        let appState = makeAppState()
        appState.selectSidebarDestination(.search)

        appState.selectPage(id: "page-1", spaceID: "space-1", revealSpaceInSidebar: true)

        #expect(appState.selectedSidebarDestination == .space("space-1"))
        #expect(appState.selectedSpaceID == "space-1")
        #expect(appState.selectedPageID == "page-1")
    }

    @Test func defaultSpaceSelectionDoesNotOverrideAnExistingSpace() {
        let appState = makeAppState()
        appState.selectedSpaceID = "space-2"
        appState.selectedSidebarDestination = .space("space-2")
        appState.spaces = [
            space(id: "space-1", name: "Product"),
            space(id: "space-2", name: "Engineering")
        ]

        appState.selectDefaultSpaceIfNeeded()

        #expect(appState.selectedSpaceID == "space-2")
        #expect(appState.selectedSidebarDestination == .space("space-2"))
    }

    @Test func defaultSpaceSelectionSeedsTheSidebarForTheFirstLoadedSpace() {
        let appState = makeAppState()
        appState.spaces = [
            space(id: "space-1", name: "Product"),
            space(id: "space-2", name: "Engineering")
        ]

        appState.selectDefaultSpaceIfNeeded()

        #expect(appState.selectedSpaceID == "space-1")
        #expect(appState.selectedSidebarDestination == .space("space-1"))
    }

    @Test func defaultSpaceSelectionReplacesAStaleSelectedSpace() {
        let appState = makeAppState()
        appState.selectedSpaceID = "deleted-space"
        appState.selectedSidebarDestination = .space("deleted-space")
        appState.selectedPageID = "page-1"
        appState.spaces = [
            space(id: "space-1", name: "Product")
        ]

        appState.selectDefaultSpaceIfNeeded()

        #expect(appState.selectedSpaceID == "space-1")
        #expect(appState.selectedSidebarDestination == .space("space-1"))
        #expect(appState.selectedPageID == nil)
    }

    private func makeAppState() -> AppState {
        let suiteName = "Docmostly.AppStateNavigationSelectionTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        userDefaults.removePersistentDomain(forName: suiteName)
        return AppState(settingsStore: LocalSettingsStore(userDefaults: userDefaults))
    }

    private func space(id: String, name: String) -> DocmostSpace {
        DocmostSpace(
            id: id,
            name: name,
            description: nil,
            logo: nil,
            slug: id,
            hostname: nil,
            creatorId: nil,
            createdAt: nil,
            updatedAt: nil,
            memberCount: nil,
            membership: nil,
            settings: nil
        )
    }
}
