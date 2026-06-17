import Foundation

nonisolated enum NativeEditorRealtimeEventEndpoint {
    static func webSocketURL(serverBaseURL: URL) throws -> URL {
        guard var components = URLComponents(url: serverBaseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }

        components.scheme = components.scheme == "https" ? "wss" : "ws"
        components.path = "/socket.io/"
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
}

nonisolated enum NativeEditorRealtimeSocketFrame: Equatable, Sendable {
    case open
    case ping
    case connected
    case disconnected
    case event(NativeEditorRealtimeEvent)
    case ignored(String)

    static let connectMessage = "40"
    static let pongMessage = "3"

    static func parse(_ text: String) throws -> NativeEditorRealtimeSocketFrame {
        let frame = text.trimmingCharacters(in: .whitespacesAndNewlines)

        switch frame {
        case "2":
            return .ping
        case "40":
            return .connected
        case "41":
            return .disconnected
        default:
            break
        }

        if frame.first == "0" {
            return .open
        }

        guard frame.hasPrefix("42") else {
            return .ignored(frame)
        }

        let payload = String(frame.dropFirst(2))
        let data = Data(payload.utf8)
        let envelope = try DocmostJSONDecoder.make().decode(SocketIOEventEnvelope.self, from: data)
        return envelope.name == "message" ? .event(envelope.event) : .ignored(envelope.name)
    }
}

nonisolated enum NativeEditorRealtimeEvent: Equatable, Sendable {
    case pageUpdated(NativeEditorRealtimePageUpdatedEvent)
    case commentCreated(NativeEditorRealtimeCommentEvent)
    case commentUpdated(NativeEditorRealtimeCommentEvent)
    case commentDeleted(NativeEditorRealtimeCommentDeletedEvent)
    case commentResolved(NativeEditorRealtimeCommentEvent)
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

nonisolated private struct SocketIOEventEnvelope: Decodable {
    let name: String
    let event: NativeEditorRealtimeEvent

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        name = try container.decode(String.self)
        event = try container.decode(NativeEditorRealtimeEvent.self)
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
