import Foundation

nonisolated struct DocmostWorkspace: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let logo: String?
    let hostname: String?
    let defaultSpaceId: String?
    let memberCount: Int?
    let plan: String?
}
