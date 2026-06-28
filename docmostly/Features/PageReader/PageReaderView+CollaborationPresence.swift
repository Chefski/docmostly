import Foundation

extension PageReaderView {
    func monitorCRDTDocumentSnapshots() async {
        guard let editorViewModel else { return }
        let snapshots = await editorViewModel.crdtDocumentSnapshots()

        for await snapshot in snapshots {
            guard Task.isCancelled == false else { return }
            editorViewModel.applyCRDTDocumentSnapshot(snapshot)
            await editorViewModel.refreshResolvedRemoteCursors()
        }
    }

    func monitorCollaborationPresence() async {
        guard let editorViewModel else { return }
        var reconnectPolicy = NativeEditorRealtimeReconnectPolicy()
        var authenticationRetry = NativeEditorCollabAuthRetry()

        while Task.isCancelled == false {
            switch await runCollaborationPresenceConnection(
                editorViewModel: editorViewModel,
                reconnectPolicy: &reconnectPolicy,
                authenticationRetry: &authenticationRetry
            ) {
            case .retryImmediately:
                continue
            case .stop:
                return
            case .reconnectLater:
                await waitBeforeCollaborationPresenceReconnect(
                    editorViewModel: editorViewModel,
                    reconnectPolicy: &reconnectPolicy
                )
            }
        }
    }

    func handleCollaborationPresenceEvent(
        _ event: NativeEditorCollaborationEvent,
        editorViewModel: NativeRichEditorViewModel
    ) async {
        switch event {
        case .authenticated(let scope):
            editorViewModel.applyCollaborationAuthenticationScope(scope)
            if scope == .unknown {
                editorViewModel.markCollaborationUnavailable("Unsupported collaboration permission scope.")
            } else if editorViewModel.usesCRDTDocumentEngine == false {
                editorViewModel.markCollaborationUnavailable("Native CRDT runtime is unavailable.")
            } else {
                markCollaborationPresenceConnected(editorViewModel)
            }
        case .awareness(let states, let localClientID):
            editorViewModel.applyAwarenessStates(states, localClientID: localClientID)
            await editorViewModel.refreshResolvedRemoteCursors()
        case .stateless(let event) where event.type == NativeEditorCollaborationDocument.statelessPageUpdatedType:
            if editorViewModel.usesCRDTDocumentEngine {
                _ = editorViewModel.handleCRDTBackedPageUpdated(event)
            } else {
                editorViewModel.markCollaborationUnavailable("Native CRDT runtime is unavailable.")
            }
        case .syncStatus(let isSynced):
            editorViewModel.applyCollaborationSyncStatus(isSynced: isSynced)
            if isSynced, editorViewModel.usesCRDTDocumentEngine == false {
                editorViewModel.markCollaborationUnavailable("Native CRDT runtime is unavailable.")
            }
        case .stateless:
            break
        }
    }

    private func markCollaborationPresenceConnected(_ editorViewModel: NativeRichEditorViewModel) {
        if editorViewModel.realtimeStatus != .conflict {
            editorViewModel.realtimeStatus = .connected
        }
    }

    private func markCollaborationPresenceConnecting(_ editorViewModel: NativeRichEditorViewModel) {
        editorViewModel.clearCollaborationPresence()
        if editorViewModel.realtimeStatus != .conflict {
            editorViewModel.realtimeStatus = .connecting
        }
    }

    private func markCollaborationPresenceAuthenticationFailed(
        _ editorViewModel: NativeRichEditorViewModel,
        message: String
    ) {
        editorViewModel.markCollaborationAuthenticationFailed(message)
    }

    private func markCollaborationPresenceFailed(
        _ editorViewModel: NativeRichEditorViewModel,
        error: any Error
    ) {
        editorViewModel.clearCollaborationPresence()

        if isConnectionFailure(error) {
            if editorViewModel.realtimeStatus != .conflict {
                editorViewModel.realtimeStatus = .disconnected
            }
            return
        }

        if editorViewModel.realtimeStatus != .conflict {
            editorViewModel.realtimeStatus = .failed(error.localizedDescription)
        }
    }

    private func handleCollaborationPresenceFailure(
        _ error: any Error,
        editorViewModel: NativeRichEditorViewModel,
        reconnectPolicy: inout NativeEditorRealtimeReconnectPolicy,
        authenticationRetry: inout NativeEditorCollabAuthRetry
    ) -> CollaborationPresenceLoopAction {
        if authenticationRetry.shouldRetryImmediately(after: error) {
            reconnectPolicy.reset()
            markCollaborationPresenceConnecting(editorViewModel)
            return .retryImmediately
        }

        if isCollaborationAuthenticationFailure(error) {
            markCollaborationPresenceAuthenticationFailed(
                editorViewModel,
                message: error.localizedDescription
            )
            return .stop
        }

        markCollaborationPresenceFailed(editorViewModel, error: error)
        return .reconnectLater
    }

    private func runCollaborationPresenceConnection(
        editorViewModel: NativeRichEditorViewModel,
        reconnectPolicy: inout NativeEditorRealtimeReconnectPolicy,
        authenticationRetry: inout NativeEditorCollabAuthRetry
    ) async -> CollaborationPresenceLoopAction {
        do {
            markCollaborationPresenceConnecting(editorViewModel)
            let events = try await collaborationPresenceEvents(editorViewModel: editorViewModel)

            for try await event in events {
                try Task.checkCancellation()
                if case .authenticated = event {
                    reconnectPolicy.reset()
                    authenticationRetry.markAuthenticated()
                }
                await handleCollaborationPresenceEvent(event, editorViewModel: editorViewModel)
            }
        } catch is CancellationError {
            return .stop
        } catch {
            return handleCollaborationPresenceFailure(
                error,
                editorViewModel: editorViewModel,
                reconnectPolicy: &reconnectPolicy,
                authenticationRetry: &authenticationRetry
            )
        }

        return .reconnectLater
    }

    private func collaborationPresenceEvents(
        editorViewModel: NativeRichEditorViewModel
    ) async throws -> AsyncThrowingStream<NativeEditorCollaborationEvent, any Error> {
        let url = try appState.collaborationWebSocketURL()
        guard let token = try await appState.loadCollaborationToken().token else {
            throw APIError.connectionFailed("Realtime collaboration token is missing.")
        }
        let collaborationSession = editorViewModel.collaborationSession()

        return await collaborationPresenceClient.events(
            url: url,
            token: token,
            documentName: collaborationSession.documentName,
            user: appState.currentUser?.user,
            syncDriver: collaborationSession.syncDriver,
            localAwarenessCursor: collaborationSession.localAwarenessCursor,
            localAwarenessUpdates: collaborationSession.localAwarenessUpdates
        )
    }

    private func waitBeforeCollaborationPresenceReconnect(
        editorViewModel: NativeRichEditorViewModel,
        reconnectPolicy: inout NativeEditorRealtimeReconnectPolicy
    ) async {
        let delaySeconds = reconnectPolicy.nextDelaySeconds()
        try? await Task.sleep(for: .seconds(delaySeconds))
        markCollaborationPresenceConnecting(editorViewModel)
    }

    private func isCollaborationAuthenticationFailure(_ error: any Error) -> Bool {
        if error is NativeEditorCollabAuthFailure {
            return true
        }

        guard let apiError = error as? APIError else { return false }
        switch apiError {
        case .httpStatus(let status, _):
            return status == 401 || status == 403
        case .connectionFailed(let message):
            return message.localizedStandardContains("token")
        case .invalidResponse, .missingData, .decodingFailed, .responseTooLarge:
            return false
        }
    }

    private func isConnectionFailure(_ error: any Error) -> Bool {
        if error is URLError {
            return true
        }

        guard let apiError = error as? APIError else { return false }
        switch apiError {
        case .connectionFailed:
            return true
        case .invalidResponse, .httpStatus, .missingData, .decodingFailed, .responseTooLarge:
            return false
        }
    }
}

private enum CollaborationPresenceLoopAction {
    case retryImmediately
    case reconnectLater
    case stop
}
