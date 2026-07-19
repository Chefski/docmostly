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

    @Test func lastSelectedSpaceIsScopedToServerAndUser() {
        let suiteName = "Docmostly.LocalSettingsStoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        userDefaults.removePersistentDomain(forName: suiteName)
        let store = LocalSettingsStore(userDefaults: userDefaults)
        let primaryScope = CacheScope(serverBaseURL: "https://docs.example.com", userID: "user-1")
        let otherUserScope = CacheScope(serverBaseURL: "https://docs.example.com", userID: "user-2")
        let otherServerScope = CacheScope(serverBaseURL: "https://notes.example.com", userID: "user-1")

        store.saveLastSelectedSpaceID("space-2", for: primaryScope)

        #expect(store.loadLastSelectedSpaceID(for: primaryScope) == "space-2")
        #expect(store.loadLastSelectedSpaceID(for: otherUserScope) == nil)
        #expect(store.loadLastSelectedSpaceID(for: otherServerScope) == nil)

        userDefaults.removePersistentDomain(forName: suiteName)
    }
}
