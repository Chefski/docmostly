import Foundation

enum NativeEditorRealtimeStatus: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case conflict
    case failed(String)
    case unsupported(String)
}

struct NativeEditorRemoteUpdate: Equatable, Sendable {
    var updatedAt: Date?
    var title: String
}

struct NativeEditorCollaborator: Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var colorName: String
}

enum NativeEditorCollaborationEndpoint {
    static func webSocketURL(serverBaseURL: URL) throws -> URL {
        guard var components = URLComponents(url: serverBaseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }

        components.scheme = webSocketScheme(for: components.scheme)
        components.path = "/collab"
        components.query = nil
        components.fragment = nil

        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    private static func webSocketScheme(for scheme: String?) -> String {
        scheme == "https" ? "wss" : "ws"
    }
}
