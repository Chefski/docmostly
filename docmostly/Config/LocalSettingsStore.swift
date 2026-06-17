import Foundation

@MainActor
final class LocalSettingsStore {
    private let userDefaults: UserDefaults
    private let serverURLKey = "Docmostly.serverURL"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadServerURLString() -> String {
        userDefaults.string(forKey: serverURLKey) ?? AppConfig.defaultServerURLString
    }

    func saveServerURLString(_ value: String) {
        userDefaults.set(value, forKey: serverURLKey)
    }
}
