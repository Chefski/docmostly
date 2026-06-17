import Foundation

nonisolated struct DocmostSearchResult: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let icon: String?
    let parentPageId: String?
    let slugId: String
    let creatorId: String?
    let createdAt: Date?
    let updatedAt: Date?
    let rank: Double?
    let highlight: String?
    let space: SearchResultSpace
}
