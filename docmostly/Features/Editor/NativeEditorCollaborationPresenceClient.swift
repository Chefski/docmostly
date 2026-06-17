import Foundation

nonisolated enum NativeEditorCollaborationEvent: Equatable, Sendable {
    case authenticated(NativeEditorCollaborationScope)
    case awareness(states: [NativeEditorAwarenessState], localClientID: Int)
    case stateless(NativeEditorCollaborationStatelessEvent)
    case syncStatus(Bool)
}

actor NativeEditorCollaborationPresenceClient {
    private let urlSession: URLSession
    private var task: URLSessionWebSocketTask?
    private var heartbeatTask: Task<Void, Never>?
    private let localClientID: Int
    private var localAwarenessClock = 0
    private var awarenessStore = NativeEditorAwarenessStateStore()

    init(
        urlSession: URLSession = .shared,
        localClientID: Int = Int.random(in: 1...Int(Int32.max))
    ) {
        self.urlSession = urlSession
        self.localClientID = localClientID
    }

    func events(
        url: URL,
        token: String,
        documentName: String,
        user: DocmostUser?
    ) -> AsyncThrowingStream<NativeEditorCollaborationEvent, any Error> {
        let streamPair = AsyncThrowingStream<NativeEditorCollaborationEvent, any Error>.makeStream(
            bufferingPolicy: .bufferingNewest(50)
        )

        let receiver = Task {
            await connect(
                url: url,
                token: token,
                documentName: documentName,
                user: user,
                continuation: streamPair.continuation
            )
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
        heartbeatTask?.cancel()
        heartbeatTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        awarenessStore.reset()
    }

    private func connect(
        url: URL,
        token: String,
        documentName: String,
        user: DocmostUser?,
        continuation: AsyncThrowingStream<NativeEditorCollaborationEvent, any Error>.Continuation
    ) async {
        disconnect()

        let task = urlSession.webSocketTask(with: URLRequest(url: url))
        self.task = task
        task.resume()

        do {
            try Task.checkCancellation()
            try await send(NativeEditorHocuspocusFrame.authentication(documentName: documentName, token: token))
            try await send(NativeEditorHocuspocusFrame.queryAwareness(documentName: documentName))
            try await sendLocalAwareness(documentName: documentName, user: user)
            startHeartbeat(documentName: documentName, user: user)
            try await receiveMessages(
                from: task,
                token: token,
                documentName: documentName,
                user: user,
                continuation: continuation
            )
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
        token: String,
        documentName: String,
        user: DocmostUser?,
        continuation: AsyncThrowingStream<NativeEditorCollaborationEvent, any Error>.Continuation
    ) async throws {
        while Task.isCancelled == false {
            let message = try await task.receive()
            let frame = try NativeEditorHocuspocusFrame.parse(Self.data(from: message))
            guard frame.documentName == documentName else { continue }

            try await handle(
                frame.message,
                token: token,
                documentName: documentName,
                user: user,
                continuation: continuation
            )
        }
    }

    private func handle(
        _ message: NativeEditorHocuspocusMessage,
        token: String,
        documentName: String,
        user: DocmostUser?,
        continuation: AsyncThrowingStream<NativeEditorCollaborationEvent, any Error>.Continuation
    ) async throws {
        switch message {
        case .authTokenRequested:
            try await send(NativeEditorHocuspocusFrame.authentication(documentName: documentName, token: token))
        case .authenticated(let scope):
            continuation.yield(.authenticated(scope))
        case .authenticationFailed(let reason):
            throw APIError.connectionFailed(reason)
        case .queryAwareness:
            try await sendLocalAwareness(documentName: documentName, user: user)
        case .awareness(let states):
            let currentStates = awarenessStore.apply(states)
            continuation.yield(.awareness(states: currentStates, localClientID: localClientID))
        case .stateless(let event):
            continuation.yield(.stateless(event))
        case .syncStatus(let isSynced):
            continuation.yield(.syncStatus(isSynced))
        case .sync:
            break
        case .close(let reason):
            throw APIError.connectionFailed(reason)
        }
    }

    private func startHeartbeat(documentName: String, user: DocmostUser?) {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while Task.isCancelled == false {
                try? await Task.sleep(for: .seconds(15))
                guard Task.isCancelled == false else { return }
                try? await self?.sendLocalAwareness(documentName: documentName, user: user)
            }
        }
    }

    private func sendLocalAwareness(documentName: String, user: DocmostUser?) async throws {
        guard let user else { return }

        localAwarenessClock += 1
        let update = try NativeEditorHocuspocusFrame.awarenessUpdate(states: [
            NativeEditorAwarenessState(
                clientID: localClientID,
                clock: localAwarenessClock,
                payload: NativeEditorAwarenessPayload(
                    user: NativeEditorAwarenessUser(
                        id: user.id,
                        name: user.name,
                        color: NativeEditorPresenceColor.color(for: user.id)
                    ),
                    cursor: nil
                )
            )
        ])
        try await send(NativeEditorHocuspocusFrame.awareness(documentName: documentName, update: update))
    }

    private func send(_ data: Data) async throws {
        guard let task else {
            throw URLError(.notConnectedToInternet)
        }
        try await task.send(.data(data))
    }

    private static func data(from message: URLSessionWebSocketTask.Message) -> Data {
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

nonisolated enum NativeEditorPresenceColor {
    static func color(for identifier: String) -> String {
        let palette = ["#6B7280", "#2563EB", "#059669", "#EA580C", "#7C3AED"]
        let index = stableHash(for: identifier) % palette.count
        return palette[index]
    }

    private static func stableHash(for value: String) -> Int {
        value.unicodeScalars.reduce(0) { result, scalar in
            ((result &* 31) &+ Int(scalar.value)) & Int.max
        }
    }
}
