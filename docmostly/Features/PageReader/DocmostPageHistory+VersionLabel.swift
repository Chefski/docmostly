import Foundation

extension DocmostPageHistory {
    var versionLabel: String {
        guard let version else { return "Saved version" }
        return "v\(version.formatted(.number))"
    }
}
