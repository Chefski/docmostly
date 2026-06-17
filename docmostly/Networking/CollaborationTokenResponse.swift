import Foundation

nonisolated struct CollaborationTokenResponse: Decodable, Sendable {
    let token: String?
}
