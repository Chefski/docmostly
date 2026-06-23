import Foundation
import Testing
@testable import docmostly

@MainActor
struct LocalSettingsStoreTests {
    @Test func savingServerURLRemembersRecentServersWithoutDuplicates() {
        let suiteName = "Docmostly.LocalSettingsStoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        userDefaults.removePersistentDomain(forName: suiteName)
        let store = LocalSettingsStore(userDefaults: userDefaults)

        store.saveServerURLString("https://docs.example.com")
        store.saveServerURLString("https://notes.example.com")
        store.saveServerURLString("https://docs.example.com")

        #expect(store.loadServerURLString() == "https://docs.example.com")
        #expect(store.loadSavedServerURLStrings() == [
            "https://docs.example.com",
            "https://notes.example.com"
        ])

        userDefaults.removePersistentDomain(forName: suiteName)
    }
}
