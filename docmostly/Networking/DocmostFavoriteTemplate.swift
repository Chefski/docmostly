import Foundation

nonisolated struct DocmostFavoriteTemplate: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let description: String?
    let icon: String?
    let spaceId: String?
}
