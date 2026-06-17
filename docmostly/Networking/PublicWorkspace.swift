import Foundation

nonisolated struct PublicWorkspace: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let logo: String?
    let hostname: String?
    let enforceSso: Bool?
}
