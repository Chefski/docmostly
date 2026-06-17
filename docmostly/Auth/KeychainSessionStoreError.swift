import Foundation
import Security

nonisolated enum KeychainSessionStoreError: Error, LocalizedError, Equatable {
    case invalidData
    case unhandledStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidData:
            "The saved session could not be read."
        case .unhandledStatus(let status):
            "Keychain returned status \(status)."
        }
    }
}
