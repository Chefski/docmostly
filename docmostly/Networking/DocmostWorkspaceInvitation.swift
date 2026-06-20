import Foundation

nonisolated struct DocmostWorkspaceInvitation: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let role: String
    let email: String
    let workspaceId: String?
    let invitedById: String?
    let createdAt: Date?
    let enforceSso: Bool?
}
