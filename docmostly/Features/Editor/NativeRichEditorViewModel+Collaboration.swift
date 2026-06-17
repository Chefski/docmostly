import Foundation

extension NativeRichEditorViewModel {
    func markRemoteBaseline(updatedAt: Date?) {
        lastRemoteUpdatedAt = updatedAt
        pendingRemotePage = nil
        pendingRemoteUpdate = nil
        realtimeStatus = .connected
    }

    func handleRemotePageSnapshot(_ page: DocmostEditablePage) {
        guard isRemotePageNewer(page) else {
            realtimeStatus = .connected
            return
        }

        if isDirty {
            pendingRemotePage = page
            pendingRemoteUpdate = NativeEditorRemoteUpdate(updatedAt: page.updatedAt, title: page.title)
            realtimeStatus = .conflict
            return
        }

        applyRemotePageSnapshot(page)
    }

    func acceptPendingRemoteUpdate() {
        guard let pendingRemotePage else { return }
        applyRemotePageSnapshot(pendingRemotePage)
    }

    func rejectPendingRemoteUpdate() {
        pendingRemotePage = nil
        pendingRemoteUpdate = nil
        realtimeStatus = .connected
    }

    private func isRemotePageNewer(_ page: DocmostEditablePage) -> Bool {
        guard let remoteUpdatedAt = page.updatedAt else { return false }
        guard let lastRemoteUpdatedAt else { return true }
        return remoteUpdatedAt > lastRemoteUpdatedAt
    }

    private func applyRemotePageSnapshot(_ page: DocmostEditablePage) {
        title = page.title
        document = NativeEditorDocument(proseMirrorDocument: page.content ?? ProseMirrorDocument())
        lastSavedTitle = title
        lastSavedDocument = document
        markRemoteBaseline(updatedAt: page.updatedAt)
        resetEditingHistory()
        isDirty = false
    }
}
