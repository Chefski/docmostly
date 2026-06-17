import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorHocuspocusProtocolTests {
    @Test func encodesAuthenticationAndQueryAwarenessFrames() throws {
        let documentName = "page.page-1"
        let authentication = try NativeEditorHocuspocusFrame.authentication(
            documentName: documentName,
            token: "abc"
        )
        let queryAwareness = NativeEditorHocuspocusFrame.queryAwareness(documentName: documentName)

        #expect(Array(authentication) == [
            11, 112, 97, 103, 101, 46, 112, 97, 103, 101, 45, 49,
            2,
            0,
            3, 97, 98, 99
        ])
        #expect(Array(queryAwareness) == [
            11, 112, 97, 103, 101, 46, 112, 97, 103, 101, 45, 49,
            3
        ])
    }

    @Test func parsesAwarenessFrameWithCollaborationCaretUser() throws {
        let payload = """
        {
          "user": {
            "id": "user-2",
            "name": "Alice",
            "color": "#2563EB"
          },
          "cursor": {
            "anchor": {
              "type": "text",
              "tname": "default",
              "item": { "client": 1, "clock": 2 },
              "assoc": 0
            },
            "head": {
              "type": "text",
              "tname": "default",
              "item": { "client": 1, "clock": 4 },
              "assoc": 0
            }
          }
        }
        """
        let frameData = makeHocuspocusFrame(
            documentName: "page.page-1",
            messageType: 1,
            payload: makeAwarenessUpdate(clientID: 42, clock: 7, stateJSON: payload)
        )

        let frame = try NativeEditorHocuspocusFrame.parse(frameData)

        guard case .awareness(let states) = frame.message else {
            Issue.record("Expected awareness message")
            return
        }

        let state = try #require(states.first)
        #expect(frame.documentName == "page.page-1")
        #expect(state.clientID == 42)
        #expect(state.clock == 7)
        #expect(state.user?.id == "user-2")
        #expect(state.user?.name == "Alice")
        #expect(state.user?.color == "#2563EB")
        let cursor = try #require(state.cursor)
        #expect(cursor.anchor?.type == .name("text"))
        #expect(cursor.anchor?.targetName == "default")
        #expect(cursor.anchor?.item == NativeEditorYjsID(client: 1, clock: 2))
        #expect(cursor.anchor?.assoc == 0)
        #expect(cursor.head?.type == .name("text"))
        #expect(cursor.head?.targetName == "default")
        #expect(cursor.head?.item == NativeEditorYjsID(client: 1, clock: 4))
        #expect(cursor.head?.assoc == 0)
    }

    @Test func parsesStatelessPageUpdatedFrame() throws {
        let payload = """
        {
          "type": "page.updated",
          "updatedAt": "2026-06-17T10:05:00.000Z",
          "lastUpdatedBy": {
            "id": "user-2",
            "name": "Alice",
            "avatarUrl": null
          }
        }
        """
        let frameData = makeHocuspocusFrame(
            documentName: "page.page-1",
            messageType: 5,
            payload: encodeVarString(payload)
        )

        let frame = try NativeEditorHocuspocusFrame.parse(frameData)

        guard case .stateless(let event) = frame.message else {
            Issue.record("Expected stateless message")
            return
        }

        #expect(event.type == "page.updated")
        #expect(event.lastUpdatedBy?.name == "Alice")
        let expectedDate = try Date(
            "2026-06-17T10:05:00.000Z",
            strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        )
        #expect(event.updatedAt == expectedDate)
    }

    @Test func parsesYjsSyncStepOneFrame() throws {
        let stateVector = Data([4, 1, 2, 3, 4])
        let frameData = makeHocuspocusFrame(
            documentName: "page.page-1",
            messageType: 0,
            payload: makeYjsSyncMessage(type: 0, update: stateVector)
        )

        let frame = try NativeEditorHocuspocusFrame.parse(frameData)

        guard case .sync(.stepOne(let parsedStateVector)) = frame.message else {
            Issue.record("Expected sync step one message")
            return
        }

        #expect(parsedStateVector == stateVector)
    }

    @Test func parsesYjsSyncStepTwoFrame() throws {
        let update = Data([6, 10, 11, 12, 13, 14, 15])
        let frameData = makeHocuspocusFrame(
            documentName: "page.page-1",
            messageType: 0,
            payload: makeYjsSyncMessage(type: 1, update: update)
        )

        let frame = try NativeEditorHocuspocusFrame.parse(frameData)

        guard case .sync(.stepTwo(let parsedUpdate)) = frame.message else {
            Issue.record("Expected sync step two message")
            return
        }

        #expect(parsedUpdate == update)
    }

    @Test func encodesYjsSyncUpdateFrame() {
        let frameData = NativeEditorHocuspocusFrame.sync(
            documentName: "page.page-1",
            message: .update(Data([9, 8, 7]))
        )

        #expect(Array(frameData) == [
            11, 112, 97, 103, 101, 46, 112, 97, 103, 101, 45, 49,
            0,
            2,
            3, 9, 8, 7
        ])
    }

    private func makeHocuspocusFrame(documentName: String, messageType: Int, payload: Data) -> Data {
        var data = Data()
        data.append(encodeVarString(documentName))
        data.append(encodeVarUint(messageType))
        data.append(payload)
        return data
    }

    private func makeAwarenessUpdate(clientID: Int, clock: Int, stateJSON: String?) -> Data {
        var update = Data()
        update.append(encodeVarUint(1))
        update.append(encodeVarUint(clientID))
        update.append(encodeVarUint(clock))
        update.append(encodeVarString(stateJSON ?? "null"))

        var payload = Data()
        payload.append(encodeVarUint(update.count))
        payload.append(update)
        return payload
    }

    private func makeYjsSyncMessage(type: Int, update: Data) -> Data {
        var data = Data()
        data.append(encodeVarUint(type))
        data.append(encodeVarUint(update.count))
        data.append(update)
        return data
    }

    private func encodeVarString(_ value: String) -> Data {
        let bytes = Data(value.utf8)
        var data = encodeVarUint(bytes.count)
        data.append(bytes)
        return data
    }

    private func encodeVarUint(_ value: Int) -> Data {
        var value = value
        var data = Data()

        while value > 0x7F {
            data.append(UInt8(0x80 | (value & 0x7F)))
            value /= 128
        }

        data.append(UInt8(value & 0x7F))
        return data
    }
}
