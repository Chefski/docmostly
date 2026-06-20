import Foundation

nonisolated struct DocmostGroup: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let groupId: String?
    let name: String
    let description: String?
    let isDefault: Bool?
    let creatorId: String?
    let workspaceId: String?
    let createdAt: Date?
    let updatedAt: Date?
    let memberCount: Int?
}
