import Foundation

nonisolated enum SettingsDestination: Hashable, Sendable {
    case account
    case workspace
    case members
    case spaces
    case groups
}
