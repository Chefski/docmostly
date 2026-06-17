import Foundation

nonisolated protocol SessionStore: Sendable {
    func save(_ session: StoredSession) async throws
    func load() async throws -> StoredSession?
    func clear() async throws
}
