import Foundation

nonisolated enum SidebarDestination: Hashable, Sendable {
    case favorites
    case notifications
    case search
    case settings
    case space(String)
}
