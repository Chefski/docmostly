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

    @Test func selectingASidebarUtilityDestinationClearsTheCurrentPage() {
        let appState = makeAppState()
        appState.selectPage(id: "page-1", spaceID: "space-1")

        appState.selectSidebarUtilityDestination(.search)

        #expect(appState.selectedSidebarDestination == .search)
        #expect(appState.selectedSpaceID == "space-1")
        #expect(appState.selectedPageID == nil)
    }

    @Test func leavingAUtilityDestinationShowsTheSidebar() {
        let appState = makeAppState()
        appState.selectSpace(id: "space-1")
        appState.selectSidebarUtilityDestination(.settings)

        appState.selectSidebarDestination(nil)

        #expect(appState.selectedSidebarDestination == nil)
        #expect(appState.selectedSpaceID == "space-1")
    }

    @Test func leavingTheSelectedPageClearsItsPageAndCommentSelection() {
        let appState = makeAppState()
        appState.selectPage(id: "page-1", commentID: "comment-1")

        appState.clearSelectedPage(ifMatching: "page-1")

        #expect(appState.selectedPageID == nil)
        #expect(appState.selectedCommentID == nil)
    }

    @Test func disappearingPreviousPageDoesNotClearNewerPageSelection() {
        let appState = makeAppState()
        appState.selectPage(id: "page-2", commentID: "comment-2")

        appState.clearSelectedPage(ifMatching: "page-1")

        #expect(appState.selectedPageID == "page-2")
        #expect(appState.selectedCommentID == "comment-2")
    }

    @Test func switchingSpacesAfterOpeningAuxiliaryPageClearsStalePageSelection() {
        let appState = makeAppState()
        let target = PageOpenTarget(
            id: "page-1",
            slugId: "roadmap",
            spaceId: "space-1",
            revealSpaceInSidebar: false
        )
        appState.selectSidebarUtilityDestination(.search)

        appState.openPage(target)
        appState.selectSidebarDestination(.space("space-2"))

        #expect(appState.selectedSidebarDestination == .space("space-2"))
        #expect(appState.selectedSpaceID == "space-2")
        #expect(appState.selectedPageID == nil)
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

    @Test func defaultSpaceSelectionRestoresTheLastSelectedSpace() {
        let (appState, scope) = makeScopedAppState()
        appState.settingsStore.saveLastSelectedSpaceID("space-2", for: scope)
        appState.spaces = [
            space(id: "space-1", name: "Product"),
            space(id: "space-2", name: "Engineering")
        ]

        appState.selectDefaultSpaceIfNeeded()

        #expect(appState.selectedSpaceID == "space-2")
        #expect(appState.selectedSidebarDestination == .space("space-2"))
    }

    @Test func selectingASpaceRemembersItForTheActiveAccount() {
        let (appState, scope) = makeScopedAppState()

        appState.selectSpace(id: "space-2")

        #expect(appState.settingsStore.loadLastSelectedSpaceID(for: scope) == "space-2")
    }

    @Test func openingAPageRemembersItsSpaceForTheActiveAccount() {
        let (appState, scope) = makeScopedAppState()

        appState.selectPage(id: "page-1", spaceID: "space-2")

        #expect(appState.settingsStore.loadLastSelectedSpaceID(for: scope) == "space-2")
    }

    @Test func defaultSpaceSelectionReplacesAnUnavailableRememberedSpace() {
        let (appState, scope) = makeScopedAppState()
        appState.settingsStore.saveLastSelectedSpaceID("deleted-space", for: scope)
        appState.spaces = [space(id: "space-1", name: "Product")]

        appState.selectDefaultSpaceIfNeeded()

        #expect(appState.selectedSpaceID == "space-1")
        #expect(appState.settingsStore.loadLastSelectedSpaceID(for: scope) == "space-1")
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

    private func makeScopedAppState() -> (AppState, CacheScope) {
        let suiteName = "Docmostly.AppStateNavigationSelectionTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        userDefaults.removePersistentDomain(forName: suiteName)
        let settingsStore = LocalSettingsStore(userDefaults: userDefaults)
        let appState = AppState(settingsStore: settingsStore)
        let scope = CacheScope(serverBaseURL: "https://docs.example.com", userID: "user-1")
        appState.configurePreviewCacheScope(scope)
        return (appState, scope)
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
