import Foundation

enum SidebarDestination: Hashable {
    case favorites
    case notifications
    case search
    case settings
    case space(String)
}
