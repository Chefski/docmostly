import Foundation

nonisolated struct DocmostNotificationSpace: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
}
