import Foundation

nonisolated struct DocmostSpace: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String?
    let logo: String?
    let slug: String
    let hostname: String?
    let creatorId: String?
    let createdAt: Date?
    let updatedAt: Date?
    let memberCount: Int?
    let membership: SpaceMembership?
    let settings: DocmostSpaceSettings?
}
