import Foundation

extension PageReaderView {
    func monitorRealtimeEvents() async {
        guard let editorViewModel else { return }
        var reconnectPolicy = NativeEditorRealtimeReconnectPolicy()

        while Task.isCancelled == false {
            do {
                let url = try appState.realtimeEventWebSocketURL()
                let cookies = await appState.activeSessionCookies(for: url)
                let events = await realtimeEventClient.events(url: url, cookies: cookies)

                for try await event in events {
                    guard Task.isCancelled == false else { return }
                    await handleRealtimeClientEvent(
                        event,
                        editorViewModel: editorViewModel,
                        reconnectPolicy: &reconnectPolicy
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                guard Task.isCancelled == false else { return }
                editorViewModel.realtimeStatus = .failed(error.localizedDescription)
            }

            await waitBeforeRealtimeReconnect(
                editorViewModel: editorViewModel,
                reconnectPolicy: &reconnectPolicy
            )
        }
    }

    func handleRealtimeClientEvent(
        _ event: NativeEditorRealtimeClientEvent,
        editorViewModel: NativeRichEditorViewModel,
        reconnectPolicy: inout NativeEditorRealtimeReconnectPolicy
    ) async {
        switch event {
        case .connected:
            reconnectPolicy.reset()
            markRealtimeConnected(editorViewModel)
        case .disconnected:
            markRealtimeConnecting(editorViewModel)
        case .event(let event):
            await handleRealtimeEvent(event, editorViewModel: editorViewModel)
        }
    }

    func handleRealtimeEvent(
        _ event: NativeEditorRealtimeEvent,
        editorViewModel: NativeRichEditorViewModel
    ) async {
        switch event {
        case .pageUpdated(let event) where event.pageID == editorViewModel.currentPageID:
            if editorViewModel.usesCRDTDocumentEngine {
                _ = editorViewModel.handleCRDTBackedPageUpdated(event)
            } else {
                editorViewModel.markCollaborationUnavailable("Native CRDT runtime is unavailable.")
            }
        case .commentCreated(let event) where event.pageID == editorViewModel.currentPageID:
            viewModel.applyCreatedComment(event.comment)
        case .commentUpdated(let event) where event.pageID == editorViewModel.currentPageID:
            viewModel.applyUpdatedComment(event.comment)
            editorViewModel.setInlineCommentResolved(
                commentID: event.comment.id,
                isResolved: event.comment.isResolved,
                tracksUndo: false
            )
        case .commentResolved(let event) where event.pageID == editorViewModel.currentPageID:
            viewModel.applyUpdatedComment(event.comment)
            editorViewModel.setInlineCommentResolved(
                commentID: event.comment.id,
                isResolved: event.comment.isResolved,
                tracksUndo: false
            )
        case .commentDeleted(let event) where event.pageID == editorViewModel.currentPageID:
            viewModel.removeComment(id: event.commentID)
            editorViewModel.removeInlineComment(commentID: event.commentID, tracksUndo: false)
        case .pageDeleted(let event) where event.pageID == editorViewModel.currentPageID:
            editorViewModel.handleRemotePageDeleted()
        case .pageUpdated, .commentCreated, .commentUpdated, .commentResolved, .commentDeleted, .pageDeleted, .unknown:
            break
        }
    }

    func waitBeforeRealtimeReconnect(
        editorViewModel: NativeRichEditorViewModel,
        reconnectPolicy: inout NativeEditorRealtimeReconnectPolicy
    ) async {
        markRealtimeConnecting(editorViewModel)
        let delaySeconds = reconnectPolicy.nextDelaySeconds()
        try? await Task.sleep(for: .seconds(delaySeconds))
    }

    private func markRealtimeConnected(_ editorViewModel: NativeRichEditorViewModel) {
        if editorViewModel.realtimeStatus != .conflict {
            editorViewModel.realtimeStatus = .connected
        }
    }

    private func markRealtimeConnecting(_ editorViewModel: NativeRichEditorViewModel) {
        if editorViewModel.realtimeStatus != .conflict {
            editorViewModel.realtimeStatus = .connecting
        }
    }
}
