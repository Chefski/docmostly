import Foundation

nonisolated struct SpaceMembership: Decodable, Hashable, Sendable {
    let userId: String?
    let role: String?
}
