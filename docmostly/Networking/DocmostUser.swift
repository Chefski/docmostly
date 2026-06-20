import Foundation

nonisolated struct DocmostUser: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let email: String?
    let avatarUrl: String?
    let role: String?
    let workspaceId: String?
    let locale: String?
    let timezone: String?
    let settings: DocmostUserSettings?
    let emailVerifiedAt: Date?
    let invitedById: String?
    let lastLoginAt: Date?
    let lastActiveAt: Date?
    let createdAt: Date?
    let updatedAt: Date?
    let deactivatedAt: Date?
    let deletedAt: Date?
    let hasGeneratedPassword: Bool?
}
