import Foundation

extension NativeEditorCollaborationPresenceClient {
    static func data(from message: URLSessionWebSocketTask.Message) throws -> Data {
        switch message {
        case .data(let data):
            guard data.count <= NativeEditorHocuspocusFrame.maximumFrameBytes else {
                throw NativeEditorHocuspocusProtocolError.payloadTooLarge
            }
            return data
        case .string(let string):
            guard string.utf8.count <= NativeEditorHocuspocusFrame.maximumFrameBytes else {
                throw NativeEditorHocuspocusProtocolError.payloadTooLarge
            }
            return Data(string.utf8)
        @unknown default:
            return Data()
        }
    }
}
