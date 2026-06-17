import Foundation

nonisolated struct CurrentUserResponse: Decodable, Hashable, Sendable {
    let user: DocmostUser
    let workspace: DocmostWorkspace
}
