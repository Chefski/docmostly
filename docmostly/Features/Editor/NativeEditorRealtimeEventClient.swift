import Foundation

nonisolated enum NativeEditorRealtimeClientEvent: Equatable, Sendable {
    case connected
    case disconnected
    case event(NativeEditorRealtimeEvent)
}

nonisolated struct NativeEditorRealtimeReconnectPolicy: Equatable, Sendable {
    private var attempt = 0
    private let delaysSeconds = [1, 2, 5, 10, 20, 30]

    mutating func nextDelaySeconds() -> Int {
        defer { attempt += 1 }
        return delaysSeconds[min(attempt, delaysSeconds.count - 1)]
    }

    mutating func reset() {
        attempt = 0
    }
}

actor NativeEditorRealtimeEventClient {
    private let urlSession: URLSession
    private var task: URLSessionWebSocketTask?

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func events(
        url: URL,
        cookies: [StoredHTTPCookie]
    ) -> AsyncThrowingStream<NativeEditorRealtimeClientEvent, any Error> {
        let streamPair = AsyncThrowingStream<NativeEditorRealtimeClientEvent, any Error>.makeStream(
            bufferingPolicy: .bufferingNewest(50)
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
        continuation: AsyncThrowingStream<NativeEditorRealtimeClientEvent, any Error>.Continuation
    ) async {
        disconnect()

        let task = urlSession.webSocketTask(with: Self.webSocketRequest(url: url, cookies: cookies))
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
        continuation: AsyncThrowingStream<NativeEditorRealtimeClientEvent, any Error>.Continuation
    ) async throws {
        while Task.isCancelled == false {
            let message = try await task.receive()
            let frame = try NativeEditorRealtimeSocketFrame.parse(Self.string(from: message))

            switch frame {
            case .open:
                try await send(NativeEditorRealtimeSocketFrame.connectMessage)
            case .ping:
                try await send(NativeEditorRealtimeSocketFrame.pongMessage)
            case .connected:
                continuation.yield(.connected)
            case .disconnected:
                continuation.yield(.disconnected)
                return
            case .unauthorized:
                throw APIError.connectionFailed("Realtime socket unauthorized.")
            case .event(let event):
                continuation.yield(.event(event))
            case .ignored:
                break
            }
        }
    }

    private func send(_ text: String) async throws {
        guard let task else {
            throw URLError(.notConnectedToInternet)
        }
        try await task.send(.string(text))
    }

    nonisolated static func string(from message: URLSessionWebSocketTask.Message) throws -> String {
        switch message {
        case .string(let text):
            guard text.count <= NativeEditorRealtimeSocketFrame.maximumFrameCharacters else {
                throw NativeEditorRealtimeSocketFrameError.frameTooLarge
            }
            text
        case .data(let data):
            guard data.count <= NativeEditorRealtimeSocketFrame.maximumFrameCharacters else {
                throw NativeEditorRealtimeSocketFrameError.frameTooLarge
            }
            String(bytes: data, encoding: .utf8) ?? ""
        @unknown default:
            ""
        }
    }

    nonisolated static func webSocketRequest(url: URL, cookies: [StoredHTTPCookie]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpShouldHandleCookies = false
        if cookies.isEmpty == false {
            request.setValue(cookieHeader(from: cookies), forHTTPHeaderField: "Cookie")
        }
        return request
    }

    private nonisolated static func cookieHeader(from cookies: [StoredHTTPCookie]) -> String {
        cookies
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "; ")
    }
}
