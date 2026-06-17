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
    var lastUpdatedBy: DocmostPagePerson?
}

enum NativeEditorCollaboratorSource: Equatable, Sendable {
    case presence
    case recentEditor
}

struct NativeEditorCollaborator: Equatable, Identifiable, Sendable {
    var id: String
    var name: String
    var colorName: String
    var source: NativeEditorCollaboratorSource

    init(
        id: String,
        name: String,
        colorName: String,
        source: NativeEditorCollaboratorSource = .presence
    ) {
        self.id = id
        self.name = name
        self.colorName = colorName
        self.source = source
    }

    init(person: DocmostPagePerson) {
        id = person.id
        name = person.name
        colorName = Self.colorName(for: person.id)
        source = .recentEditor
    }

    init(awarenessState: NativeEditorAwarenessState) {
        let user = awarenessState.payload?.user
        let identifier = user?.id ?? "client-\(awarenessState.clientID)"
        id = identifier
        name = user?.name ?? "Someone"
        colorName = user?.color ?? Self.colorName(for: identifier)
        source = .presence
    }

    private static func colorName(for identifier: String) -> String {
        let palette = ["gray", "blue", "green", "orange", "purple"]
        let index = abs(identifier.hashValue) % palette.count
        return palette[index]
    }
}

enum NativeEditorPresenceStatusText {
    static func editingTitle(for collaborators: [NativeEditorCollaborator]) -> String? {
        let names = collaborators
            .filter { $0.source == .presence }
            .map(\.name)

        guard let firstName = names.first else { return nil }

        switch names.count {
        case 1:
            return "\(firstName) is editing"
        case 2:
            return "\(firstName) and \(names[1]) are editing"
        default:
            return "\(firstName) and \(names.count - 1) others are editing"
        }
    }
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
