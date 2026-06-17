import Testing
@testable import docmostly

struct NativeEditorAwarenessStateStoreTests {
    @Test func keepsAwarenessStateAcrossIncrementalUpdatesAndRemovals() {
        var store = NativeEditorAwarenessStateStore()
        let alice = awarenessState(
            clientID: 42,
            clock: 1,
            userID: "user-2",
            name: "Alice",
            color: "#2563EB"
        )
        let bob = awarenessState(
            clientID: 43,
            clock: 1,
            userID: "user-3",
            name: "Bob",
            color: "#059669"
        )

        #expect(store.apply([alice]).map(\.clientID) == [42])
        #expect(store.apply([bob]).map(\.clientID) == [42, 43])
        #expect(store.apply([
            NativeEditorAwarenessState(clientID: 42, clock: 2, payload: nil)
        ]).map(\.clientID) == [43])
    }

    @Test func ignoresStaleAwarenessUpdatesByClientClock() {
        var store = NativeEditorAwarenessStateStore()
        let latestAlice = awarenessState(
            clientID: 42,
            clock: 3,
            userID: "user-2",
            name: "Alice",
            color: "#2563EB"
        )
        let staleAlice = awarenessState(
            clientID: 42,
            clock: 2,
            userID: "user-2",
            name: "Old Alice",
            color: "#EA580C"
        )

        #expect(store.apply([latestAlice]).first?.user?.name == "Alice")
        #expect(store.apply([staleAlice]).first?.user?.name == "Alice")
        #expect(store.apply([
            NativeEditorAwarenessState(clientID: 42, clock: 2, payload: nil)
        ]).map(\.clientID) == [42])
        #expect(store.apply([
            NativeEditorAwarenessState(clientID: 42, clock: 4, payload: nil)
        ]).isEmpty)
        #expect(store.apply([latestAlice]).isEmpty)
    }

    private func awarenessState(
        clientID: Int,
        clock: Int,
        userID: String,
        name: String,
        color: String
    ) -> NativeEditorAwarenessState {
        NativeEditorAwarenessState(
            clientID: clientID,
            clock: clock,
            payload: NativeEditorAwarenessPayload(
                user: NativeEditorAwarenessUser(id: userID, name: name, color: color),
                cursor: nil
            )
        )
    }
}
