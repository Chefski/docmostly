import Foundation

@MainActor
final class LocalSettingsStore {
    private let userDefaults: UserDefaults
    private let serverURLKey = "Docmostly.serverURL"
    private let savedServerURLsKey = "Docmostly.savedServerURLs"

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

    private func rememberServerURLString(_ value: String) {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else { return }

        let savedValues = loadSavedServerURLStrings().filter { $0 != trimmedValue }
        userDefaults.set([trimmedValue] + savedValues, forKey: savedServerURLsKey)
    }
}
