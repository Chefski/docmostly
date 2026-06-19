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
            do {
                markCollaborationPresenceConnecting(editorViewModel)
                let url = try appState.collaborationWebSocketURL()
                guard let token = try await appState.loadCollaborationToken().token else {
                    throw APIError.connectionFailed("Realtime collaboration token is missing.")
                }
                let collaborationSession = editorViewModel.collaborationSession()

                let events = await collaborationPresenceClient.events(
                    url: url,
                    token: token,
                    documentName: collaborationSession.documentName,
                    user: appState.currentUser?.user,
                    syncDriver: collaborationSession.syncDriver,
                    localAwarenessCursor: collaborationSession.localAwarenessCursor,
                    localAwarenessUpdates: collaborationSession.localAwarenessUpdates
                )

                for try await event in events {
                    guard Task.isCancelled == false else { return }
                    if case .authenticated = event {
                        reconnectPolicy.reset()
                        authenticationRetry.markAuthenticated()
                    }
                    await handleCollaborationPresenceEvent(event, editorViewModel: editorViewModel)
                }
            } catch is CancellationError {
                return
            } catch {
                guard Task.isCancelled == false else { return }

                if authenticationRetry.shouldRetryImmediately(after: error) {
                    reconnectPolicy.reset()
                    markCollaborationPresenceConnecting(editorViewModel)
                    continue
                }

                markCollaborationPresenceUnsupported(editorViewModel, message: error.localizedDescription)
            }

            await waitBeforeCollaborationPresenceReconnect(
                editorViewModel: editorViewModel,
                reconnectPolicy: &reconnectPolicy
            )
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
                markCollaborationPresenceUnsupported(
                    editorViewModel,
                    message: "Unsupported collaboration permission scope."
                )
            } else {
                markCollaborationPresenceConnected(editorViewModel)
            }
        case .awareness(let states, let localClientID):
            editorViewModel.applyAwarenessStates(states, localClientID: localClientID)
            await editorViewModel.refreshResolvedRemoteCursors()
        case .stateless(let event) where event.type == NativeEditorCollaborationDocument.statelessPageUpdatedType:
            if editorViewModel.handleCRDTBackedPageUpdated(event) == false {
                await refreshRemotePageSnapshot(editorViewModel: editorViewModel, lastUpdatedBy: event.lastUpdatedBy)
            }
        case .syncStatus(let isSynced):
            editorViewModel.applyCollaborationSyncStatus(isSynced: isSynced)
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

    private func markCollaborationPresenceUnsupported(
        _ editorViewModel: NativeRichEditorViewModel,
        message: String
    ) {
        editorViewModel.clearCollaborationPresence()
        if editorViewModel.realtimeStatus != .conflict {
            editorViewModel.realtimeStatus = .unsupported(message)
        }
    }

    private func waitBeforeCollaborationPresenceReconnect(
        editorViewModel: NativeRichEditorViewModel,
        reconnectPolicy: inout NativeEditorRealtimeReconnectPolicy
    ) async {
        let delaySeconds = reconnectPolicy.nextDelaySeconds()
        try? await Task.sleep(for: .seconds(delaySeconds))
        markCollaborationPresenceConnecting(editorViewModel)
    }
}
