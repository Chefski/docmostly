import Foundation

nonisolated struct UnreadNotificationCountResponse: Decodable, Hashable, Sendable {
    let count: Int
}
