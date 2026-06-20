import Foundation

nonisolated struct DocmostFavorite: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let userId: String
    let pageId: String?
    let spaceId: String?
    let templateId: String?
    let type: FavoriteType
    let workspaceId: String
    let createdAt: Date?
    let page: DocmostFavoritePage?
    let space: DocmostFavoriteSpace?
    let template: DocmostFavoriteTemplate?
}
