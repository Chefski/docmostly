import Foundation

actor NativeEditorCollaborationPresenceClient {
    private let urlSession: URLSession
    private var task: URLSessionWebSocketTask?
    private var heartbeatTask: Task<Void, Never>?
    private var localUpdateTask: Task<Void, Never>?
    private var localAwarenessUpdateTask: Task<Void, Never>?
    private var awarenessPruneTask: Task<Void, Never>?
    private var authenticatedScope: NativeEditorCollaborationScope?
    private let localClientID: Int
    private var localAwarenessClock = 0
    private var activeDocumentName: String?
    private var hasSentLocalAwareness = false
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
        awarenessPruneTask?.cancel()
        awarenessPruneTask = nil
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        authenticatedScope = nil
        activeDocumentName = nil
        hasSentLocalAwareness = false
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
        startAwarenessPruner(continuation: continuation)

        do {
            try Task.checkCancellation()
            try await send(
                NativeEditorHocuspocusFrame.authentication(
                    documentName: context.documentName,
                    token: context.token
                )
            )
            try await send(NativeEditorHocuspocusFrame.queryAwareness(documentName: context.documentName))
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
            try await handleAuthenticatedScope(scope, context: context, continuation: continuation)
        case .authenticationFailed(let reason):
            throw NativeEditorCollabAuthFailure(reason: reason)
        case .queryAwareness:
            guard authenticatedScope?.allowsLocalAwarenessUpdates == true else { return }
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
    func handleAuthenticatedScope(
        _ scope: NativeEditorCollaborationScope,
        context: NativeEditorCollaborationSessionContext,
        continuation: AsyncThrowingStream<NativeEditorCollaborationEvent, any Error>.Continuation
    ) async throws {
        authenticatedScope = scope
        try await sendInitialCRDTSync(using: context.syncDriver)
        configureLocalDocumentUpdates(for: scope, syncDriver: context.syncDriver)
        try await configureLocalAwarenessUpdates(for: scope, context: context)
        continuation.yield(.authenticated(scope))
    }

    func configureLocalDocumentUpdates(
        for scope: NativeEditorCollaborationScope,
        syncDriver: NativeEditorCollaborationSyncDriver?
    ) {
        if scope.allowsLocalDocumentUpdates {
            startLocalUpdateSender(using: syncDriver)
        } else {
            stopLocalUpdateSender()
        }
    }

    func configureLocalAwarenessUpdates(
        for scope: NativeEditorCollaborationScope,
        context: NativeEditorCollaborationSessionContext
    ) async throws {
        if scope.allowsLocalAwarenessUpdates {
            try await sendLocalAwareness(context: context)
            startHeartbeat(context: context)
            startLocalAwarenessUpdateSender(context: context)
        } else {
            try? await sendLocalAwarenessRemovalIfNeeded(documentName: context.documentName)
            stopHeartbeat()
            stopLocalAwarenessUpdateSender()
        }
    }

    func disconnectGracefully() async {
        if let activeDocumentName {
            try? await sendLocalAwarenessRemovalIfNeeded(documentName: activeDocumentName)
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

    func stopLocalAwarenessUpdateSender() {
        localAwarenessUpdateTask?.cancel()
        localAwarenessUpdateTask = nil
    }

    func stopHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = nil
    }

    func stopAwarenessPruner() {
        awarenessPruneTask?.cancel()
        awarenessPruneTask = nil
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
        stopLocalAwarenessUpdateSender()

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
        stopHeartbeat()
        heartbeatTask = Task { [weak self, context] in
            while Task.isCancelled == false {
                try? await Task.sleep(for: NativeEditorAwarenessTiming.localStateRefreshDelay)
                guard Task.isCancelled == false else { return }
                try? await self?.sendLocalAwareness(context: context)
            }
        }
    }

    func startAwarenessPruner(
        continuation: AsyncThrowingStream<NativeEditorCollaborationEvent, any Error>.Continuation
    ) {
        stopAwarenessPruner()
        awarenessPruneTask = Task { [weak self] in
            while Task.isCancelled == false {
                try? await Task.sleep(for: NativeEditorAwarenessTiming.staleStateCheckDelay)
                guard Task.isCancelled == false else { return }
                await self?.pruneStaleAwarenessStates(continuation: continuation)
            }
        }
    }

    func pruneStaleAwarenessStates(
        continuation: AsyncThrowingStream<NativeEditorCollaborationEvent, any Error>.Continuation
    ) {
        guard let states = awarenessStore.pruneStaleStates() else { return }
        continuation.yield(.awareness(states: states, localClientID: localClientID))
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
        hasSentLocalAwareness = true
    }

    func sendLocalAwarenessRemovalIfNeeded(documentName: String) async throws {
        guard hasSentLocalAwareness else { return }

        localAwarenessClock += 1
        let frame = try NativeEditorHocuspocusFrame.awarenessRemoval(
            documentName: documentName,
            clientID: localClientID,
            clock: localAwarenessClock
        )
        try await send(frame)
        hasSentLocalAwareness = false
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
