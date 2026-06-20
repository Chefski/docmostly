import Foundation

nonisolated struct DocmostFavoriteSpace: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let slug: String
    let logo: String?
}
