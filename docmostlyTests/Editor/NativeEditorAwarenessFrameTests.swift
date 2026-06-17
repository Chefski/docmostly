import Testing
@testable import docmostly

struct NativeEditorAwarenessFrameTests {
    @Test func encodesAwarenessRemovalFrameAsYjsNullState() throws {
        let frameData = try NativeEditorHocuspocusFrame.awarenessRemoval(
            documentName: "page.page-1",
            clientID: 42,
            clock: 9
        )

        let frame = try NativeEditorHocuspocusFrame.parse(frameData)

        guard case .awareness(let states) = frame.message else {
            Issue.record("Expected awareness removal message.")
            return
        }

        let state = try #require(states.first)
        #expect(states.count == 1)
        #expect(frame.documentName == "page.page-1")
        #expect(state.clientID == 42)
        #expect(state.clock == 9)
        #expect(state.payload == nil)
    }
}
