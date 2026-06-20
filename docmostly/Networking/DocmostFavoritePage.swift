import Foundation

nonisolated struct DocmostFavoritePage: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let slugId: String
    let title: String
    let icon: String?
    let spaceId: String
}
