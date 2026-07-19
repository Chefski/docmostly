import Foundation

nonisolated enum NotificationSocketEvent: Equatable, Sendable {
    case connected
    case notification
    case disconnected
}

actor NotificationSocketClient {
    private let urlSession: URLSession
    private var task: URLSessionWebSocketTask?

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func events(
        url: URL,
        cookies: [StoredHTTPCookie]
    ) -> AsyncThrowingStream<NotificationSocketEvent, any Error> {
        let streamPair = AsyncThrowingStream<NotificationSocketEvent, any Error>.makeStream(
            bufferingPolicy: .bufferingNewest(10)
        )
        let receiver = Task {
            await connect(url: url, cookies: cookies, continuation: streamPair.continuation)
        }

        streamPair.continuation.onTermination = { _ in
            receiver.cancel()
            Task {
                await self.disconnect()
            }
        }
        return streamPair.stream
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func connect(
        url: URL,
        cookies: [StoredHTTPCookie],
        continuation: AsyncThrowingStream<NotificationSocketEvent, any Error>.Continuation
    ) async {
        disconnect()
        let task = urlSession.webSocketTask(with: Self.request(url: url, cookies: cookies))
        self.task = task
        task.resume()

        do {
            try await receiveMessages(from: task, continuation: continuation)
            continuation.finish()
        } catch is CancellationError {
            continuation.finish()
        } catch {
            continuation.finish(throwing: error)
        }
        disconnect()
    }

    private func receiveMessages(
        from task: URLSessionWebSocketTask,
        continuation: AsyncThrowingStream<NotificationSocketEvent, any Error>.Continuation
    ) async throws {
        while Task.isCancelled == false {
            let message = try await task.receive()
            switch try Self.parse(Self.string(from: message)) {
            case .open:
                try await send("40")
            case .ping:
                try await send("3")
            case .connected:
                continuation.yield(.connected)
            case .notification:
                continuation.yield(.notification)
            case .disconnected:
                continuation.yield(.disconnected)
                return
            case .unauthorized:
                throw APIError.connectionFailed("Notification socket unauthorized.")
            case .ignored:
                break
            }
        }
    }

    private func send(_ message: String) async throws {
        guard let task else { throw URLError(.notConnectedToInternet) }
        try await task.send(.string(message))
    }

    private nonisolated static func request(
        url: URL,
        cookies: [StoredHTTPCookie]
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpShouldHandleCookies = false
        if cookies.isEmpty == false {
            let cookieHeader = cookies
                .map { "\($0.name)=\($0.value)" }
                .joined(separator: "; ")
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }
        return request
    }

    private nonisolated static func string(from message: URLSessionWebSocketTask.Message) throws -> String {
        switch message {
        case .string(let text):
            guard text.count <= 1_000_000 else { throw URLError(.dataLengthExceedsMaximum) }
            return text
        case .data(let data):
            guard data.count <= 1_000_000 else { throw URLError(.dataLengthExceedsMaximum) }
            return String(bytes: data, encoding: .utf8) ?? ""
        @unknown default:
            return ""
        }
    }

    private nonisolated static func parse(_ text: String) throws -> NotificationSocketFrame {
        let frame = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if frame == "2" { return .ping }
        if frame == "41" { return .disconnected }
        if frame.first == "0" { return .open }
        if frame.hasPrefix("40") { return .connected }
        guard frame.hasPrefix("42") else { return .ignored }

        let data = Data(frame.dropFirst(2).utf8)
        let envelope = try JSONDecoder().decode(NotificationSocketEnvelope.self, from: data)
        if envelope.name == "notification" { return .notification }
        if envelope.name == "Unauthorized" { return .unauthorized }
        return .ignored
    }
}

nonisolated private enum NotificationSocketFrame: Sendable {
    case open
    case ping
    case connected
    case notification
    case disconnected
    case unauthorized
    case ignored
}

nonisolated private struct NotificationSocketEnvelope: Decodable, Sendable {
    let name: String

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        name = try container.decode(String.self)
    }
}
