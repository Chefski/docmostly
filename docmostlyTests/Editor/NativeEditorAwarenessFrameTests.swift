import Foundation
import Testing
@testable import docmostly

struct NativeEditorAwarenessFrameTests {
    @Test func relativePositionJSONPreservesExplicitNullBoundariesForYjs() throws {
        let position = NativeEditorYjsRelativePosition(
            type: nil,
            targetName: NativeEditorCollaborationDocument.yjsFragmentName,
            item: nil,
            assoc: 0
        )

        let object = try #require(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(position)) as? [String: Any]
        )

        #expect(object["item"] is NSNull)
        #expect(object["type"] is NSNull)
        #expect(object["tname"] as? String == NativeEditorCollaborationDocument.yjsFragmentName)
        #expect(object["assoc"] as? Int == 0)
    }

    @Test func nestedYjsTypeTargetsPageFragmentWhileAnotherNamedRootDoesNot() {
        let nestedPosition = NativeEditorYjsRelativePosition(
            type: .id(NativeEditorYjsID(client: 7, clock: 1)),
            targetName: nil,
            item: NativeEditorYjsID(client: 7, clock: 2),
            assoc: 0
        )
        let otherRootPosition = NativeEditorYjsRelativePosition(
            type: nil,
            targetName: "another-fragment",
            item: nil,
            assoc: 0
        )

        #expect(nestedPosition.targetsDocmostDefaultFragment)
        #expect(otherRootPosition.targetsDocmostDefaultFragment == false)
    }

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
