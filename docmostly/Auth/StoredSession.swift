import Foundation

nonisolated struct StoredSession: Codable, Equatable, Sendable {
    let serverBaseURL: URL
    let cookies: [StoredHTTPCookie]
    /// Last known signed-in user, kept so the app can restore its offline cache scope without network access.
    var currentUser: CurrentUserResponse?
}
