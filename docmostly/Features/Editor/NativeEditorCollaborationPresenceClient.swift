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
    let localAwarenessUpdates: AsyncStream<Void>?
}

actor NativeEditorCollaborationPresenceClient {
    private let urlSession: URLSession
    private var task: URLSessionWebSocketTask?
    private var heartbeatTask: Task<Void, Never>?
    private var localUpdateTask: Task<Void, Never>?
    private var localAwarenessUpdateTask: Task<Void, Never>?
    private var authenticatedScope: NativeEditorCollaborationScope?
    private let localClientID: Int
    private var localAwarenessClock = 0
    private var activeDocumentName: String?
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
        localAwarenessCursor: (@Sendable () async -> NativeEditorAwarenessCursor?)? = nil,
        localAwarenessUpdates: AsyncStream<Void>? = nil
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
            localAwarenessCursor: localAwarenessCursor,
            localAwarenessUpdates: localAwarenessUpdates
        )

        let receiver = Task {
            await connect(
                context: context,
                continuation: streamPair.continuation
            )
        }

        streamPair.continuation.onTermination = { _ in
            Task {
                await self.disconnectGracefully()
                receiver.cancel()
            }
        }

        return streamPair.stream
    }

    func disconnect() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
        localUpdateTask?.cancel()
        localUpdateTask = nil
        localAwarenessUpdateTask?.cancel()
        localAwarenessUpdateTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        authenticatedScope = nil
        activeDocumentName = nil
        awarenessStore.reset()
    }

    private func connect(
        context: NativeEditorCollaborationSessionContext,
        continuation: AsyncThrowingStream<NativeEditorCollaborationEvent, any Error>.Continuation
    ) async {
        await disconnectGracefully()

        let task = urlSession.webSocketTask(with: URLRequest(url: context.url))
        self.task = task
        activeDocumentName = context.documentName
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
            authenticatedScope = scope
            try await sendInitialCRDTSync(using: context.syncDriver)
            if scope.allowsLocalDocumentUpdates {
                startLocalUpdateSender(using: context.syncDriver)
            } else {
                stopLocalUpdateSender()
            }
            startLocalAwarenessUpdateSender(context: context)
            continuation.yield(.authenticated(scope))
        case .authenticationFailed(let reason):
            throw NativeEditorCollabAuthFailure(reason: reason)
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
            try await sendCRDTSyncReply(
                for: syncMessage,
                authenticatedScope: authenticatedScope,
                using: context.syncDriver
            )
        case .close(let reason):
            throw APIError.connectionFailed(reason)
        }
    }
}

private extension NativeEditorCollaborationPresenceClient {
    func disconnectGracefully() async {
        if let activeDocumentName {
            try? await sendLocalAwarenessRemoval(documentName: activeDocumentName)
        }

        disconnect()
    }

    func sendInitialCRDTSync(using syncDriver: NativeEditorCollaborationSyncDriver?) async throws {
        guard let syncDriver else { return }
        let frames = try await syncDriver.outboundFramesAfterAuthentication()
        try await send(frames)
    }

    func sendCRDTSyncReply(
        for message: NativeEditorYjsSyncMessage,
        authenticatedScope: NativeEditorCollaborationScope?,
        using syncDriver: NativeEditorCollaborationSyncDriver?
    ) async throws {
        guard let syncDriver else { return }
        guard authenticatedScope?.allowsSyncReply(to: message) ?? false else { return }
        let frames = try await syncDriver.outboundFrames(for: message)
        try await send(frames)
    }

    func stopLocalUpdateSender() {
        localUpdateTask?.cancel()
        localUpdateTask = nil
    }

    func startLocalUpdateSender(using syncDriver: NativeEditorCollaborationSyncDriver?) {
        stopLocalUpdateSender()

        guard let syncDriver else { return }

        localUpdateTask = Task { [weak self, syncDriver] in
            let updates = await syncDriver.localUpdates()

            for await update in updates {
                guard Task.isCancelled == false else { return }
                let frame = await syncDriver.outboundFrame(forLocalUpdate: update)

                do {
                    try await self?.send(frame)
                } catch {
                    return
                }
            }
        }
    }

    func startLocalAwarenessUpdateSender(context: NativeEditorCollaborationSessionContext) {
        localAwarenessUpdateTask?.cancel()
        localAwarenessUpdateTask = nil

        guard let updates = context.localAwarenessUpdates else { return }

        localAwarenessUpdateTask = Task { [weak self, context, updates] in
            for await _ in updates {
                guard Task.isCancelled == false else { return }

                do {
                    try await self?.sendLocalAwareness(context: context)
                } catch {
                    return
                }
            }
        }
    }

    func startHeartbeat(context: NativeEditorCollaborationSessionContext) {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self, context] in
            while Task.isCancelled == false {
                try? await Task.sleep(for: .seconds(15))
                guard Task.isCancelled == false else { return }
                try? await self?.sendLocalAwareness(context: context)
            }
        }
    }

    func sendLocalAwareness(context: NativeEditorCollaborationSessionContext) async throws {
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

    func sendLocalAwarenessRemoval(documentName: String) async throws {
        localAwarenessClock += 1
        let frame = try NativeEditorHocuspocusFrame.awarenessRemoval(
            documentName: documentName,
            clientID: localClientID,
            clock: localAwarenessClock
        )
        try await send(frame)
    }

    func send(_ data: Data) async throws {
        guard let task else {
            throw URLError(.notConnectedToInternet)
        }
        try await task.send(.data(data))
    }

    func send(_ frames: [Data]) async throws {
        for frame in frames {
            try await send(frame)
        }
    }

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
