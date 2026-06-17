import Foundation

extension NativeRichEditorViewModel {
    func markRemoteBaseline(updatedAt: Date?) {
        lastRemoteUpdatedAt = updatedAt
        pendingRemotePage = nil
        pendingRemoteUpdate = nil
        realtimeStatus = .connected
    }

    func handleRemotePageSnapshot(
        _ page: DocmostEditablePage,
        lastUpdatedBy fallbackLastUpdatedBy: DocmostPagePerson? = nil
    ) {
        guard isRemotePageNewer(page) else {
            realtimeStatus = .connected
            return
        }

        let lastUpdatedBy = page.lastUpdatedBy ?? fallbackLastUpdatedBy

        if isDirty {
            pendingRemotePage = page
            pendingRemoteUpdate = NativeEditorRemoteUpdate(
                updatedAt: page.updatedAt,
                title: page.title,
                lastUpdatedBy: lastUpdatedBy
            )
            realtimeStatus = .conflict
            return
        }

        applyRemotePageSnapshot(page, lastUpdatedBy: lastUpdatedBy)
    }

    func acceptPendingRemoteUpdate() {
        guard let pendingRemotePage else { return }
        applyRemotePageSnapshot(pendingRemotePage, lastUpdatedBy: pendingRemoteUpdate?.lastUpdatedBy)
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

    private func applyRemotePageSnapshot(_ page: DocmostEditablePage, lastUpdatedBy: DocmostPagePerson?) {
        title = page.title
        document = NativeEditorDocument(proseMirrorDocument: page.content ?? ProseMirrorDocument())
        lastSavedTitle = title
        lastSavedDocument = document
        activeCollaborators = collaborators(from: lastUpdatedBy)
        markRemoteBaseline(updatedAt: page.updatedAt)
        resetEditingHistory()
        isDirty = false
    }

    private func collaborators(from person: DocmostPagePerson?) -> [NativeEditorCollaborator] {
        guard let person else { return [] }
        return [NativeEditorCollaborator(person: person)]
    }
}
