import Foundation

nonisolated struct DocmostUser: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let email: String?
    let avatarUrl: String?
    let role: String?
    let workspaceId: String?
    let locale: String?
}
