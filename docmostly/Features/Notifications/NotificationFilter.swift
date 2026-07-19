import Foundation

nonisolated enum NotificationFilter: String, CaseIterable, Identifiable, Sendable {
    case all
    case unread

    var id: Self { self }

    var title: String {
        switch self {
        case .all:
            "All"
        case .unread:
            "Unread"
        }
    }
}
