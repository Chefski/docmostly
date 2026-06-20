import Foundation

nonisolated struct DocmostSpaceMember: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let email: String?
    let avatarUrl: String?
    let role: String
    let type: String
    let isDefault: Bool?
    let memberCount: Int?
}
