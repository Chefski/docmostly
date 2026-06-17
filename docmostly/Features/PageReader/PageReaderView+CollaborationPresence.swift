import Foundation

extension PageReaderView {
    func monitorCollaborationPresence() async {
        guard let editorViewModel else { return }

        do {
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
                syncDriver: collaborationSession.syncDriver
            )

            for try await event in events {
                guard Task.isCancelled == false else { return }
                await handleCollaborationPresenceEvent(event, editorViewModel: editorViewModel)
            }
        } catch is CancellationError {
            return
        } catch {
            guard Task.isCancelled == false else { return }
            editorViewModel.realtimeStatus = .unsupported(error.localizedDescription)
        }
    }

    func handleCollaborationPresenceEvent(
        _ event: NativeEditorCollaborationEvent,
        editorViewModel: NativeRichEditorViewModel
    ) async {
        switch event {
        case .authenticated:
            markCollaborationPresenceConnected(editorViewModel)
        case .awareness(let states, let localClientID):
            editorViewModel.applyAwarenessStates(states, localClientID: localClientID)
        case .stateless(let event) where event.type == "page.updated":
            await refreshRemotePageSnapshot(editorViewModel: editorViewModel, lastUpdatedBy: event.lastUpdatedBy)
        case .stateless, .syncStatus:
            break
        }
    }

    private func markCollaborationPresenceConnected(_ editorViewModel: NativeRichEditorViewModel) {
        if editorViewModel.realtimeStatus != .conflict {
            editorViewModel.realtimeStatus = .connected
        }
    }
}
