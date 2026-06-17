import Foundation

nonisolated struct DocmostPagePerson: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let avatarUrl: String?
}
