import Foundation

nonisolated struct CurrentUserResponse: Codable, Hashable, Sendable {
    let user: DocmostUser
    let workspace: DocmostWorkspace
}
