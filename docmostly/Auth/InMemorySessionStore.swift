import Foundation

actor InMemorySessionStore: SessionStore {
    private var session: StoredSession?

    func save(_ session: StoredSession) async throws {
        self.session = session
    }

    func load() async throws -> StoredSession? {
        session
    }

    func clear() async throws {
        session = nil
    }
}
