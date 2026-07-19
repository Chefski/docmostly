import Testing
@testable import docmostly

@MainActor
struct AppStatePageDiscoveryTests {
    @Test func markingPageDiscoveryChangedAdvancesItsRevision() {
        let appState = AppState()
        let initialRevision = appState.pageDiscoveryRevision

        appState.markPageDiscoveryChanged()

        #expect(appState.pageDiscoveryRevision == initialRevision + 1)
    }

    @Test func pageDiscoveryRevisionChangesTheBrowserTaskIdentity() {
        let initialKey = PageBrowserTaskKey(
            spaceID: "space-1",
            scope: .recentlyUpdated,
            pageDiscoveryRevision: 0
        )
        let refreshedKey = PageBrowserTaskKey(
            spaceID: "space-1",
            scope: .recentlyUpdated,
            pageDiscoveryRevision: 1
        )

        #expect(initialKey != refreshedKey)
    }
}
