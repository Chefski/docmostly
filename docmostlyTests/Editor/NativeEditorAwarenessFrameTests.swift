import Foundation
import Testing
@testable import docmostly

struct NativeEditorAwarenessFrameTests {
    @Test func encodesMissingAwarenessCursorAsExplicitNull() throws {
        let update = try NativeEditorHocuspocusFrame.awarenessUpdate(states: [
            NativeEditorAwarenessState(
                clientID: 42,
                clock: 10,
                payload: NativeEditorAwarenessPayload(
                    user: NativeEditorAwarenessUser(
                        id: "user-1",
                        name: "Alice",
                        color: "#c0ffee"
                    ),
                    cursor: nil
                )
            )
        ])

        var decoder = NativeEditorLib0Decoder(data: update)
        #expect(try decoder.readVarUint() == 1)
        #expect(try decoder.readVarUint() == 42)
        #expect(try decoder.readVarUint() == 10)

        let json = try decoder.readVarString()
        let payload = try #require(
            JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]
        )

        #expect(payload.keys.contains("cursor"))
        #expect(payload["cursor"] is NSNull)
    }

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
