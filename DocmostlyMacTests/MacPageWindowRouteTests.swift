import Foundation
import Testing
@testable import DocmostlyMac

@MainActor
struct MacPageWindowRouteTests {
    @Test func selectedPageCreatesAWindowRouteWithCurrentSpaceContext() {
        let state = makeAppState()
        state.selectPage(id: "page-slug", spaceID: "space-1", revealSpaceInSidebar: true)

        let route = MacPageWindowRoute.selectedPageRoute(from: state)

        #expect(route?.pageID == "page-slug")
        #expect(route?.spaceID == "space-1")
    }

    @Test func routeIsUnavailableWithoutASelectedPage() {
        let state = makeAppState()
        state.selectSpace(id: "space-1")

        #expect(MacPageWindowRoute.selectedPageRoute(from: state) == nil)
    }

    @Test func routeIsUnavailableWithoutASelectedSpace() {
        let state = makeAppState()
        state.selectPage(id: "page-slug")

        #expect(MacPageWindowRoute.selectedPageRoute(from: state) == nil)
    }

    private func makeAppState() -> AppState {
        let suiteName = "Docmostly.MacPageWindowRouteTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        userDefaults.removePersistentDomain(forName: suiteName)
        return AppState(settingsStore: LocalSettingsStore(userDefaults: userDefaults))
    }
}
