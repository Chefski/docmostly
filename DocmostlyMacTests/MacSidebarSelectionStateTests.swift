import Testing
@testable import DocmostlyMac

struct MacSidebarSelectionStateTests {
    @Test func utilitySelectionStaysVisibleWhenAPageIsOpenFromThatUtility() {
        let state = MacSidebarSelectionState(
            destination: .search,
            selectedPageID: "page-1"
        )

        #expect(state.isUtilitySelected(.search))
        #expect(state.isPageSelected(slugID: "page-1", spaceID: "space-1") == false)
    }

    @Test func pageTreeSelectionOnlyAppliesWhenTheSpaceDestinationIsActive() {
        let state = MacSidebarSelectionState(
            destination: .space("space-1"),
            selectedPageID: "page-1"
        )

        #expect(state.isOverviewSelected(spaceID: "space-1") == false)
        #expect(state.isPageSelected(slugID: "page-1", spaceID: "space-1"))
        #expect(state.isPageSelected(slugID: "page-1", spaceID: "space-2") == false)
    }

    @Test func overviewSelectionRequiresTheActiveSpaceAndNoSelectedPage() {
        let state = MacSidebarSelectionState(
            destination: .space("space-1"),
            selectedPageID: nil
        )

        #expect(state.isOverviewSelected(spaceID: "space-1"))
        #expect(state.isOverviewSelected(spaceID: "space-2") == false)
    }
}
