import Foundation

@MainActor
final class LocalSettingsStore {
    private let userDefaults: UserDefaults
    private let serverURLKey = "Docmostly.serverURL"
    private let savedServerURLsKey = "Docmostly.savedServerURLs"
    private let lastSelectedSpaceIDsKey = "Docmostly.lastSelectedSpaceIDs"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadServerURLString() -> String {
        userDefaults.string(forKey: serverURLKey) ?? AppConfig.defaultServerURLString
    }

    func saveServerURLString(_ value: String) {
        userDefaults.set(value, forKey: serverURLKey)
        rememberServerURLString(value)
    }

    func loadSavedServerURLStrings() -> [String] {
        userDefaults.stringArray(forKey: savedServerURLsKey) ?? []
    }

    func loadLastSelectedSpaceID(for scope: CacheScope) -> String? {
        lastSelectedSpaceIDs[selectionScopeKey(for: scope)]
    }

    func saveLastSelectedSpaceID(_ spaceID: String, for scope: CacheScope) {
        var selectedSpaceIDs = lastSelectedSpaceIDs
        selectedSpaceIDs[selectionScopeKey(for: scope)] = spaceID
        userDefaults.set(selectedSpaceIDs, forKey: lastSelectedSpaceIDsKey)
    }

    private var lastSelectedSpaceIDs: [String: String] {
        userDefaults.dictionary(forKey: lastSelectedSpaceIDsKey) as? [String: String] ?? [:]
    }

    private func selectionScopeKey(for scope: CacheScope) -> String {
        "\(scope.serverBaseURL)\n\(scope.userID)"
    }

    private func rememberServerURLString(_ value: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else { return }

        let savedValues = loadSavedServerURLStrings().filter { $0 != trimmedValue }
        userDefaults.set([trimmedValue] + savedValues, forKey: savedServerURLsKey)
    }
}
