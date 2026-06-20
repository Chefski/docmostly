import Foundation

nonisolated struct DocmostNotificationActor: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let avatarUrl: String?
}
