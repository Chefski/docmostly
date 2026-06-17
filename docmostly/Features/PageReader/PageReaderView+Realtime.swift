import Foundation

extension PageReaderView {
    func monitorRealtimeEvents() async {
        guard let editorViewModel else { return }

        do {
            let url = try appState.realtimeEventWebSocketURL()
            let cookies = await appState.storedSessionCookies()
            let events = await realtimeEventClient.events(url: url, cookies: cookies)

            for try await event in events {
                guard Task.isCancelled == false else { return }
                await handleRealtimeEvent(event, editorViewModel: editorViewModel)
            }
        } catch {
            guard Task.isCancelled == false else { return }
            editorViewModel.realtimeStatus = .unsupported(error.localizedDescription)
        }
    }

    func handleRealtimeEvent(
        _ event: NativeEditorRealtimeEvent,
        editorViewModel: NativeRichEditorViewModel
    ) async {
        switch event {
        case .pageUpdated(let event) where event.pageID == editorViewModel.currentPageID:
            await refreshRemotePageSnapshot(
                editorViewModel: editorViewModel,
                lastUpdatedBy: event.lastUpdatedBy
            )
        case .commentCreated(let event) where event.pageID == editorViewModel.currentPageID:
            viewModel.applyCreatedComment(event.comment)
        case .commentUpdated(let event) where event.pageID == editorViewModel.currentPageID:
            viewModel.applyUpdatedComment(event.comment)
        case .commentResolved(let event) where event.pageID == editorViewModel.currentPageID:
            viewModel.applyUpdatedComment(event.comment)
            editorViewModel.setInlineCommentResolved(
                commentID: event.comment.id,
                isResolved: event.comment.isResolved,
                tracksUndo: false
            )
        case .commentDeleted(let event) where event.pageID == editorViewModel.currentPageID:
            viewModel.removeComment(id: event.commentID)
        case .pageUpdated, .commentCreated, .commentUpdated, .commentResolved, .commentDeleted, .unknown:
            break
        }
    }

    func refreshRemotePageSnapshot(
        editorViewModel: NativeRichEditorViewModel,
        lastUpdatedBy: DocmostPagePerson? = nil
    ) async {
        do {
            let page = try await appState.loadEditablePage(idOrSlugId: editorViewModel.currentPageID)
            editorViewModel.handleRemotePageSnapshot(page, lastUpdatedBy: lastUpdatedBy)
        } catch {
            editorViewModel.realtimeStatus = .failed(error.localizedDescription)
        }
    }
}
