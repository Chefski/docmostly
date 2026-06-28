import Testing
@testable import DocmostlyMac

@MainActor
struct MacPageWindowRouteTests {
    @Test func selectedPageCreatesAWindowRouteWithCurrentSpaceContext() {
        let state = AppState()
        state.selectPage(id: "page-slug", spaceID: "space-1", revealSpaceInSidebar: true)

        let route = MacPageWindowRoute.selectedPageRoute(from: state)

        #expect(route?.pageID == "page-slug")
        #expect(route?.spaceID == "space-1")
    }

    @Test func routeIsUnavailableWithoutASelectedPage() {
        let state = AppState()
        state.selectSpace(id: "space-1")

        #expect(MacPageWindowRoute.selectedPageRoute(from: state) == nil)
    }
}
