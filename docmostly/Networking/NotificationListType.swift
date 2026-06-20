import Foundation

nonisolated enum NotificationListType: String, Codable, CaseIterable, Sendable {
    case direct
    case updates
    case all
}
