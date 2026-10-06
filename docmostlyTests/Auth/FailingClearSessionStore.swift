import Foundation
import Synchronization
@testable import docmostly

/// Session store whose `clear()` can be made to fail, simulating a Keychain deletion error.
nonisolated final class FailingClearSessionStore: SessionStore {
    struct ClearError: Error {}

    private struct State {
        var session: StoredSession?
        var clearShouldFail: Bool
    }

    private let state: Mutex<State>

    init(session: StoredSession? = nil, clearShouldFail: Bool = true) {
        state = Mutex(State(session: session, clearShouldFail: clearShouldFail))
    }

    func setClearShouldFail(_ value: Bool) {
        state.withLock { $0.clearShouldFail = value }
    }

    func save(_ session: StoredSession) async throws {
        state.withLock { $0.session = session }
    }

    func load() async throws -> StoredSession? {
        state.withLock { $0.session }
    }

    func clear() async throws {
        try state.withLock { state in
            if state.clearShouldFail {
                throw ClearError()
            }
            state.session = nil
        }
    }
}
