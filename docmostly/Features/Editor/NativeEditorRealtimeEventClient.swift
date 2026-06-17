import Foundation

actor NativeEditorRealtimeEventClient {
    private let urlSession: URLSession
    private var task: URLSessionWebSocketTask?

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    func events(
        url: URL,
        cookies: [StoredHTTPCookie]
    ) -> AsyncThrowingStream<NativeEditorRealtimeEvent, any Error> {
        AsyncThrowingStream { continuation in
            let receiver = Task {
                await connect(url: url, cookies: cookies, continuation: continuation)
            }

            continuation.onTermination = { _ in
                receiver.cancel()
                Task {
                    await self.disconnect()
                }
            }
        }
    }

    func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func connect(
        url: URL,
        cookies: [StoredHTTPCookie],
        continuation: AsyncThrowingStream<NativeEditorRealtimeEvent, any Error>.Continuation
    ) async {
        var request = URLRequest(url: url)
        request.httpShouldHandleCookies = true
        if cookies.isEmpty == false {
            request.setValue(Self.cookieHeader(from: cookies), forHTTPHeaderField: "Cookie")
        }

        let task = urlSession.webSocketTask(with: request)
        self.task = task
        task.resume()

        do {
            try await receiveMessages(from: task, continuation: continuation)
            continuation.finish()
        } catch {
            continuation.finish(throwing: error)
        }
    }

    private func receiveMessages(
        from task: URLSessionWebSocketTask,
        continuation: AsyncThrowingStream<NativeEditorRealtimeEvent, any Error>.Continuation
    ) async throws {
        while Task.isCancelled == false {
            let message = try await task.receive()
            let frame = try NativeEditorRealtimeSocketFrame.parse(Self.string(from: message))

            switch frame {
            case .open:
                try await send(NativeEditorRealtimeSocketFrame.connectMessage)
            case .ping:
                try await send(NativeEditorRealtimeSocketFrame.pongMessage)
            case .event(let event):
                continuation.yield(event)
            case .connected, .disconnected, .ignored:
                break
            }
        }
    }

    private func send(_ text: String) async throws {
        try await task?.send(.string(text))
    }

    private static func string(from message: URLSessionWebSocketTask.Message) -> String {
        switch message {
        case .string(let text):
            text
        case .data(let data):
            String(bytes: data, encoding: .utf8) ?? ""
        @unknown default:
            ""
        }
    }

    private static func cookieHeader(from cookies: [StoredHTTPCookie]) -> String {
        cookies
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "; ")
    }
}
