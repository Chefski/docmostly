import Foundation

nonisolated struct StoredSession: Codable, Equatable, Sendable {
    let serverBaseURL: URL
    let cookies: [StoredHTTPCookie]
}
