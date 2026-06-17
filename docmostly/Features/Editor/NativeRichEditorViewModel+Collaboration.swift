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

    func handleCRDTBackedPageUpdated(_ event: NativeEditorCollaborationStatelessEvent) -> Bool {
        guard crdtDocumentEngine != nil else { return false }

        markRemoteBaseline(updatedAt: event.updatedAt ?? lastRemoteUpdatedAt)
        return true
    }

    func crdtDocumentSnapshots() async -> AsyncStream<NativeEditorCRDTDocumentSnapshot> {
        guard let crdtDocumentEngine else {
            let (stream, continuation) = AsyncStream.makeStream(of: NativeEditorCRDTDocumentSnapshot.self)
            continuation.finish()
            return stream
        }

        return await crdtDocumentEngine.documentSnapshots()
    }

    func applyCRDTDocumentSnapshot(_ snapshot: NativeEditorCRDTDocumentSnapshot) {
        let wasDirty = isDirty

        if let title = snapshot.title {
            self.title = title
        }
        document = snapshot.document
        pendingRemotePage = nil
        pendingRemoteUpdate = nil
        resolvedRemoteCursors = []
        markRemoteBaseline(updatedAt: snapshot.updatedAt ?? lastRemoteUpdatedAt)
        resetEditingHistory()

        if wasDirty {
            isDirty = true
        } else {
            lastSavedTitle = self.title
            lastSavedDocument = document
            isDirty = false
        }
    }

    func applyAwarenessStates(_ states: [NativeEditorAwarenessState], localClientID: Int) {
        var seenIDs: Set<String> = []
        activeCollaborators = states.compactMap { state in
            guard state.clientID != localClientID, state.payload?.user != nil else { return nil }

            let collaborator = NativeEditorCollaborator(awarenessState: state)
            guard seenIDs.insert(collaborator.id).inserted else { return nil }
            return collaborator
        }

        var seenCursorIDs: Set<String> = []
        remoteCursors = states.compactMap { state in
            guard state.clientID != localClientID else { return nil }
            guard let remoteCursor = NativeEditorRemoteCursor(awarenessState: state) else { return nil }
            guard seenCursorIDs.insert(remoteCursor.id).inserted else { return nil }
            return remoteCursor
        }
        resolvedRemoteCursors = []

        if realtimeStatus != .conflict {
            realtimeStatus = .connected
        }
    }

    func configureCRDTDocumentEngine(_ engine: any NativeEditorCRDTDocumentEngine) {
        crdtDocumentEngine = engine
    }

    func collaborationSession() -> NativeEditorCollaborationSession {
        let collaborationDocument = NativeEditorCollaborationDocument(pageID: currentPageID)
        let syncDriver = crdtDocumentEngine.map { engine in
            NativeEditorCollaborationSyncDriver(
                documentName: collaborationDocument.name,
                coordinator: NativeEditorCRDTSyncCoordinator(documentEngine: engine)
            )
        }
        return NativeEditorCollaborationSession(
            document: collaborationDocument,
            syncDriver: syncDriver,
            localAwarenessCursor: { [weak self] in
                await self?.localAwarenessCursor()
            }
        )
    }

    func refreshResolvedRemoteCursors() async {
        guard let crdtDocumentEngine else {
            resolvedRemoteCursors = []
            return
        }

        var resolvedCursors: [NativeEditorResolvedRemoteCursor] = []
        resolvedCursors.reserveCapacity(remoteCursors.count)

        for cursor in remoteCursors {
            if let resolvedCursor = try? await crdtDocumentEngine.resolveRemoteCursor(cursor) {
                resolvedCursors.append(resolvedCursor)
            }
        }

        resolvedRemoteCursors = resolvedCursors
    }

    func currentLocalTextSelection() -> NativeEditorLocalTextSelection? {
        guard let index = activeBlockIndex else { return nil }
        let block = document.blocks[index]
        return NativeEditorLocalTextSelection(
            blockIndex: index,
            selection: block.selection,
            text: block.text
        )
    }

    func localAwarenessCursor() async -> NativeEditorAwarenessCursor? {
        guard let crdtDocumentEngine else { return nil }
        guard let selection = currentLocalTextSelection() else { return nil }
        return try? await crdtDocumentEngine.encodeLocalAwarenessCursor(for: selection)
    }

    func inlineCommentYjsSelection(for context: NativeEditorInlineCommentContext) async -> NativeEditorYjsSelection? {
        guard let crdtDocumentEngine else { return nil }
        guard let blockIndex = document.blocks.firstIndex(where: { $0.id == context.blockID }) else { return nil }
        guard let selection = NativeEditorLocalTextSelection(
            blockIndex: blockIndex,
            selection: context.selection,
            text: document.blocks[blockIndex].text
        ) else { return nil }
        guard selection.isCollapsed == false else { return nil }
        return try? await crdtDocumentEngine.encodeInlineCommentSelection(for: selection)
    }

    func resolvedCursorsForBlock(id blockID: UUID) -> [NativeEditorResolvedRemoteCursor] {
        guard let blockIndex = document.blocks.firstIndex(where: { $0.id == blockID }) else { return [] }

        return resolvedRemoteCursors.filter { cursor in
            let lowerBound = min(cursor.anchor.blockIndex, cursor.head.blockIndex)
            let upperBound = max(cursor.anchor.blockIndex, cursor.head.blockIndex)
            return (lowerBound...upperBound).contains(blockIndex)
        }
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
        remoteCursors = []
        resolvedRemoteCursors = []
        markRemoteBaseline(updatedAt: page.updatedAt)
        resetEditingHistory()
        isDirty = false
    }

    private func collaborators(from person: DocmostPagePerson?) -> [NativeEditorCollaborator] {
        guard let person else { return [] }
        return [NativeEditorCollaborator(person: person)]
    }
}
