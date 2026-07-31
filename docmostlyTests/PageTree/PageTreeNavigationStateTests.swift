import Testing
@testable import docmostly

struct PageTreeNavigationStateTests {
    @Test func openingSpaceSettingsStoresTheSelectedSpaceID() {
        var state = PageTreeNavigationState()

        state.showSpaceSettings(spaceID: "space-1")

        #expect(state.spaceSettingsSpaceID == "space-1")
    }

    @Test func openingDifferentSpaceSettingsReplacesThePreviousDestination() {
        var state = PageTreeNavigationState(spaceSettingsSpaceID: "space-1")

        state.showSpaceSettings(spaceID: "space-2")

        #expect(state.spaceSettingsSpaceID == "space-2")
    }
}
