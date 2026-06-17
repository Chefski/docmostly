import Foundation

nonisolated enum NativeEditorCollaborationEvent: Equatable, Sendable {
    case authenticated(NativeEditorCollaborationScope)
    case awareness(states: [NativeEditorAwarenessState], localClientID: Int)
    case stateless(NativeEditorCollaborationStatelessEvent)
    case syncStatus(Bool)
}

private struct NativeEditorCollaborationSessionContext: Sendable {
    let url: URL
    let token: String
    let documentName: String
    let user: DocmostUser?
    let syncDriver: NativeEditorCollaborationSyncDriver?
    let localAwarenessCursor: (@Sendable () async -> NativeEditorAwarenessCursor?)?
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
        user: DocmostUser?,
        syncDriver: NativeEditorCollaborationSyncDriver? = nil,
        localAwarenessCursor: (@Sendable () async -> NativeEditorAwarenessCursor?)? = nil
    ) -> AsyncThrowingStream<NativeEditorCollaborationEvent, any Error> {
        let streamPair = AsyncThrowingStream<NativeEditorCollaborationEvent, any Error>.makeStream(
            bufferingPolicy: .bufferingNewest(50)
        )
        let context = NativeEditorCollaborationSessionContext(
            url: url,
            token: token,
            documentName: documentName,
            user: user,
            syncDriver: syncDriver,
            localAwarenessCursor: localAwarenessCursor
        )

        let receiver = Task {
            await connect(
                context: context,
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
        context: NativeEditorCollaborationSessionContext,
        continuation: AsyncThrowingStream<NativeEditorCollaborationEvent, any Error>.Continuation
    ) async {
        disconnect()

        let task = urlSession.webSocketTask(with: URLRequest(url: context.url))
        self.task = task
        task.resume()

        do {
            try Task.checkCancellation()
            try await send(
                NativeEditorHocuspocusFrame.authentication(
                    documentName: context.documentName,
                    token: context.token
                )
            )
            try await send(NativeEditorHocuspocusFrame.queryAwareness(documentName: context.documentName))
            try await sendLocalAwareness(context: context)
            startHeartbeat(context: context)
            try await receiveMessages(
                from: task,
                context: context,
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
        context: NativeEditorCollaborationSessionContext,
        continuation: AsyncThrowingStream<NativeEditorCollaborationEvent, any Error>.Continuation
    ) async throws {
        while Task.isCancelled == false {
            let message = try await task.receive()
            let frame = try NativeEditorHocuspocusFrame.parse(Self.data(from: message))
            guard frame.documentName == context.documentName else { continue }

            try await handle(
                frame.message,
                context: context,
                continuation: continuation
            )
        }
    }

    private func handle(
        _ message: NativeEditorHocuspocusMessage,
        context: NativeEditorCollaborationSessionContext,
        continuation: AsyncThrowingStream<NativeEditorCollaborationEvent, any Error>.Continuation
    ) async throws {
        switch message {
        case .authTokenRequested:
            try await send(
                NativeEditorHocuspocusFrame.authentication(
                    documentName: context.documentName,
                    token: context.token
                )
            )
        case .authenticated(let scope):
            try await sendInitialCRDTSync(using: context.syncDriver)
            continuation.yield(.authenticated(scope))
        case .authenticationFailed(let reason):
            throw APIError.connectionFailed(reason)
        case .queryAwareness:
            try await sendLocalAwareness(context: context)
        case .awareness(let states):
            let currentStates = awarenessStore.apply(states)
            continuation.yield(.awareness(states: currentStates, localClientID: localClientID))
        case .stateless(let event):
            continuation.yield(.stateless(event))
        case .syncStatus(let isSynced):
            continuation.yield(.syncStatus(isSynced))
        case .sync(let syncMessage):
            try await sendCRDTSyncReply(for: syncMessage, using: context.syncDriver)
        case .close(let reason):
            throw APIError.connectionFailed(reason)
        }
    }

    private func sendInitialCRDTSync(using syncDriver: NativeEditorCollaborationSyncDriver?) async throws {
        guard let syncDriver else { return }
        let frames = try await syncDriver.outboundFramesAfterAuthentication()
        try await send(frames)
    }

    private func sendCRDTSyncReply(
        for message: NativeEditorYjsSyncMessage,
        using syncDriver: NativeEditorCollaborationSyncDriver?
    ) async throws {
        guard let syncDriver else { return }
        let frames = try await syncDriver.outboundFrames(for: message)
        try await send(frames)
    }

    private func startHeartbeat(context: NativeEditorCollaborationSessionContext) {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self, context] in
            while Task.isCancelled == false {
                try? await Task.sleep(for: .seconds(15))
                guard Task.isCancelled == false else { return }
                try? await self?.sendLocalAwareness(context: context)
            }
        }
    }

    private func sendLocalAwareness(context: NativeEditorCollaborationSessionContext) async throws {
        let cursor = await context.localAwarenessCursor?()
        let documentName = context.documentName
        let user = context.user
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
                    cursor: cursor
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

    private func send(_ frames: [Data]) async throws {
        for frame in frames {
            try await send(frame)
        }
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
