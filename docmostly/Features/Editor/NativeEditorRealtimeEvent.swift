import Foundation

nonisolated enum NativeEditorRealtimeEventEndpoint {
    static func webSocketURL(serverBaseURL: URL) throws -> URL {
        guard var components = URLComponents(url: serverBaseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }

        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = webSocketPath(basePath: components.path, endpointPath: "socket.io")
        components.queryItems = [
            URLQueryItem(name: "EIO", value: "4"),
            URLQueryItem(name: "transport", value: "websocket")
        ]
        components.fragment = nil

        guard let url = components.url else {
            throw URLError(.badURL)
        }
        return url
    }

    private static func webSocketPath(basePath: String, endpointPath: String) -> String {
        let trimmedBase = basePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard trimmedBase.isEmpty == false else {
            return "/\(endpointPath)/"
        }
        return "/\(trimmedBase)/\(endpointPath)/"
    }
}

nonisolated enum NativeEditorRealtimeSocketFrameError: Error, Equatable, Sendable {
    case frameTooLarge
}

nonisolated enum NativeEditorRealtimeSocketFrame: Equatable, Sendable {
    case open
    case ping
    case connected
    case disconnected
    case unauthorized
    case event(NativeEditorRealtimeEvent)
    case ignored(String)

    static let connectMessage = "40"
    static let pongMessage = "3"
    static let maximumFrameCharacters = 1_000_000

    static func parse(_ text: String) throws -> NativeEditorRealtimeSocketFrame {
        guard text.count <= maximumFrameCharacters else {
            throw NativeEditorRealtimeSocketFrameError.frameTooLarge
        }
        let frame = text.trimmingCharacters(in: .whitespacesAndNewlines)

        switch frame {
        case "2":
            return .ping
        case "41":
            return .disconnected
        default:
            break
        }

        if frame.first == "0" {
            return .open
        }

        if frame.hasPrefix("40") {
            return .connected
        }

        guard frame.hasPrefix("42") else {
            return .ignored(frame)
        }

        return try parseEventFrame(frame)
    }

    private static func parseEventFrame(_ frame: String) throws -> NativeEditorRealtimeSocketFrame {
        let payload = String(frame.dropFirst(2))
        let data = Data(payload.utf8)
        let envelope = try DocmostJSONDecoder.make().decode(SocketIOEventEnvelope.self, from: data)

        switch envelope.name {
        case "message":
            guard let event = envelope.event else { return .ignored(envelope.name) }
            return .event(event)
        case "Unauthorized":
            return .unauthorized
        default:
            return .ignored(envelope.name)
        }
    }
}

nonisolated enum NativeEditorRealtimeEvent: Equatable, Sendable {
    case pageUpdated(NativeEditorRealtimePageUpdatedEvent)
    case commentCreated(NativeEditorRealtimeCommentEvent)
    case commentUpdated(NativeEditorRealtimeCommentEvent)
    case commentDeleted(NativeEditorRealtimeCommentDeletedEvent)
    case commentResolved(NativeEditorRealtimeCommentEvent)
    case pageDeleted(NativeEditorRealtimePageDeletedEvent)
    case unknown(String)
}

nonisolated struct NativeEditorRealtimePageUpdatedEvent: Equatable, Sendable {
    let pageID: String
    let spaceID: String?
    let title: String?
    let slugID: String?
    let updatedAt: Date?
    let lastUpdatedBy: DocmostPagePerson?
}

nonisolated struct NativeEditorRealtimeCommentEvent: Equatable, Sendable {
    let pageID: String
    let comment: DocmostComment
}

nonisolated struct NativeEditorRealtimeCommentDeletedEvent: Equatable, Sendable {
    let pageID: String
    let commentID: String
}

nonisolated struct NativeEditorRealtimePageDeletedEvent: Equatable, Sendable {
    let pageID: String
    let spaceID: String?
}

nonisolated private struct SocketIOEventEnvelope: Decodable {
    let name: String
    let event: NativeEditorRealtimeEvent?

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        name = try container.decode(String.self)
        event = container.isAtEnd ? nil : try container.decode(NativeEditorRealtimeEvent.self)
    }
}

nonisolated extension NativeEditorRealtimeEvent: Decodable {
    private enum CodingKeys: String, CodingKey {
        case operation
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let operation = try container.decode(String.self, forKey: .operation)

        switch operation {
        case "updateOne":
            let event = try PageUpdateEventEnvelope(from: decoder)
            self = event.isPageUpdate ? .pageUpdated(event.realtimeEvent) : .unknown(operation)
        case "commentCreated":
            let event = try CommentEventEnvelope(from: decoder)
            self = .commentCreated(event.realtimeEvent)
        case "commentUpdated":
            let event = try CommentEventEnvelope(from: decoder)
            self = .commentUpdated(event.realtimeEvent)
        case "commentResolved":
            let event = try CommentEventEnvelope(from: decoder)
            self = .commentResolved(event.realtimeEvent)
        case "commentDeleted":
            let event = try CommentDeletedEventEnvelope(from: decoder)
            self = .commentDeleted(event.realtimeEvent)
        case "deleteTreeNode":
            let event = try DeleteTreeNodeEventEnvelope(from: decoder)
            self = .pageDeleted(event.realtimeEvent)
        default:
            self = .unknown(operation)
        }
    }
}

nonisolated private struct PageUpdateEventEnvelope: Decodable {
    let spaceId: String?
    let entity: [String]
    let id: String
    let payload: PagePayload

    var isPageUpdate: Bool {
        entity.first == "pages"
    }

    var realtimeEvent: NativeEditorRealtimePageUpdatedEvent {
        NativeEditorRealtimePageUpdatedEvent(
            pageID: id,
            spaceID: spaceId,
            title: payload.title,
            slugID: payload.slugId,
            updatedAt: payload.updatedAt,
            lastUpdatedBy: payload.lastUpdatedBy
        )
    }

    struct PagePayload: Decodable {
        let title: String?
        let slugId: String?
        let updatedAt: Date?
        let lastUpdatedBy: DocmostPagePerson?
    }
}

nonisolated private struct CommentEventEnvelope: Decodable {
    let pageId: String
    let comment: DocmostComment

    var realtimeEvent: NativeEditorRealtimeCommentEvent {
        NativeEditorRealtimeCommentEvent(pageID: pageId, comment: comment)
    }
}

nonisolated private struct CommentDeletedEventEnvelope: Decodable {
    let pageId: String
    let commentId: String

    var realtimeEvent: NativeEditorRealtimeCommentDeletedEvent {
        NativeEditorRealtimeCommentDeletedEvent(pageID: pageId, commentID: commentId)
    }
}

nonisolated private struct DeleteTreeNodeEventEnvelope: Decodable {
    let spaceId: String?
    let payload: Payload

    var realtimeEvent: NativeEditorRealtimePageDeletedEvent {
        NativeEditorRealtimePageDeletedEvent(pageID: payload.node.id, spaceID: spaceId)
    }

    struct Payload: Decodable {
        let node: Node
    }

    struct Node: Decodable {
        let id: String
    }
}
