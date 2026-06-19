import Foundation

extension NativeEditorCollaborationPresenceClient {
    static func data(from message: URLSessionWebSocketTask.Message) -> Data {
        switch message {
        case .data(let data):
            data
        case .string(let string):
            Data(string.utf8)
        @unknown default:
            Data()
        }
    }
}
