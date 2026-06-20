import Foundation

nonisolated struct DocmostNotificationPage: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let slugId: String
    let icon: String?
}
