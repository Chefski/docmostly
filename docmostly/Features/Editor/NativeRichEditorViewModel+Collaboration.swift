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
        applyPagePermissions(page.permissions)

        guard usesCRDTDocumentEngine == false else {
            if realtimeStatus != .conflict {
                realtimeStatus = .connected
            }
            return
        }

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

    func needsRemoteSnapshotRefresh(forCreatedComment comment: DocmostComment) -> Bool {
        false
    }

    func acceptPendingRemoteUpdate() {
        if let pendingRemotePage {
            applyRemotePageSnapshot(pendingRemotePage, lastUpdatedBy: pendingRemoteUpdate?.lastUpdatedBy)
            return
        }

        guard let pendingRemoteUpdate else { return }
        applyPendingRemoteTitleUpdate(pendingRemoteUpdate)
    }

    func rejectPendingRemoteUpdate() {
        pendingRemotePage = nil
        pendingRemoteUpdate = nil
        realtimeStatus = .connected
    }

    func clearCollaborationPresence() {
        activeCollaborators.removeAll { $0.source == .presence }
        remoteCursors = []
        resolvedRemoteCursors = []
    }

    func applyCollaborationSyncStatus(isSynced: Bool) {
        if isSynced == false {
            clearCollaborationPresence()
        }

        guard realtimeStatus != .conflict else { return }
        realtimeStatus = isSynced ? .connected : .connecting
    }

    func handleCRDTBackedPageUpdated(_ event: NativeEditorCollaborationStatelessEvent) -> Bool {
        handleCRDTBackedPageUpdated(
            updatedAt: event.updatedAt,
            lastUpdatedBy: event.lastUpdatedBy
        )
    }

    func handleCRDTBackedPageUpdated(_ event: NativeEditorRealtimePageUpdatedEvent) -> Bool {
        handleCRDTBackedPageUpdated(
            updatedAt: event.updatedAt,
            title: event.title,
            lastUpdatedBy: event.lastUpdatedBy
        )
    }

    func handleCRDTBackedPageUpdated(
        updatedAt: Date?,
        lastUpdatedBy: DocmostPagePerson?
    ) -> Bool {
        handleCRDTBackedPageUpdated(
            updatedAt: updatedAt,
            title: nil,
            lastUpdatedBy: lastUpdatedBy
        )
    }

    private func handleCRDTBackedPageUpdated(
        updatedAt: Date?,
        title remoteTitle: String?,
        lastUpdatedBy: DocmostPagePerson?
    ) -> Bool {
        guard crdtDocumentEngine != nil else { return false }
        guard isCRDTPageUpdateNewer(updatedAt) else {
            if realtimeStatus != .conflict {
                realtimeStatus = .connected
            }
            return true
        }

        recordRecentEditor(from: lastUpdatedBy)

        if let remoteTitle {
            applyCRDTBackedRemoteTitle(
                remoteTitle,
                updatedAt: updatedAt,
                lastUpdatedBy: lastUpdatedBy
            )
            return true
        }

        markRemoteBaseline(updatedAt: updatedAt ?? lastRemoteUpdatedAt)
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
        let presenceCollaborators: [NativeEditorCollaborator] = states.compactMap { state in
            guard state.clientID != localClientID, state.payload?.user != nil else { return nil }

            let collaborator = NativeEditorCollaborator(awarenessState: state)
            guard seenIDs.insert(collaborator.id).inserted else { return nil }
            return collaborator
        }
        let presenceIDs = Set(presenceCollaborators.map { $0.id })
        let recentEditors = activeCollaborators.filter { collaborator in
            collaborator.source == .recentEditor && presenceIDs.contains(collaborator.id) == false
        }
        activeCollaborators = presenceCollaborators + recentEditors

        var seenCursorIDs: Set<String> = []
        remoteCursors = states.compactMap { state in
            guard state.clientID != localClientID else { return nil }
            guard let remoteCursor = NativeEditorRemoteCursor(awarenessState: state) else { return nil }
            guard seenCursorIDs.insert(remoteCursor.id).inserted else { return nil }
            return remoteCursor
        }
        resolvedRemoteCursors = []

        switch realtimeStatus {
        case .conflict, .authenticationFailed, .failed:
            break
        case .connected, .connecting, .disconnected:
            realtimeStatus = .connected
        }
    }

    func configureCRDTDocumentEngine(_ engine: any NativeEditorCRDTDocumentEngine) {
        crdtDocumentEngine = engine
        crdtSyncCoordinator = NativeEditorCRDTSyncCoordinator(documentEngine: engine)
    }

    var usesCRDTDocumentEngine: Bool {
        crdtDocumentEngine != nil
    }

    func localAwarenessUpdates() -> AsyncStream<Void> {
        localAwarenessUpdateStream
    }

    func notifyLocalAwarenessChanged() {
        localAwarenessUpdateContinuation.yield(())
    }

    func handleLocalSelectionChanged() {
        guard canEdit else { return }
        notifyLocalAwarenessChanged()
    }

    func collaborationSession() -> NativeEditorCollaborationSession {
        let collaborationDocument = NativeEditorCollaborationDocument(pageID: currentPageID)
        let syncDriver = crdtSyncCoordinator.map { coordinator in
            NativeEditorCollaborationSyncDriver(
                documentName: collaborationDocument.name,
                coordinator: coordinator
            )
        }
        return NativeEditorCollaborationSession(
            document: collaborationDocument,
            syncDriver: syncDriver,
            localAwarenessCursor: { [weak self] in
                await self?.localAwarenessCursor()
            },
            localAwarenessUpdates: localAwarenessUpdates()
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
        resolvedRemoteCursorsByBlockID[blockID] ?? []
    }

    func rebuildResolvedRemoteCursorIndex() {
        guard resolvedRemoteCursors.isEmpty == false else {
            resolvedRemoteCursorsByBlockID = [:]
            return
        }

        var blockIDsByIndex: [Int: UUID] = [:]
        blockIDsByIndex.reserveCapacity(document.blocks.count)
        for (index, block) in document.blocks.enumerated() {
            blockIDsByIndex[index] = block.id
        }

        var cursorsByBlockID: [UUID: [NativeEditorResolvedRemoteCursor]] = [:]
        for cursor in resolvedRemoteCursors {
            let lowerBound = min(cursor.anchor.blockIndex, cursor.head.blockIndex)
            let upperBound = max(cursor.anchor.blockIndex, cursor.head.blockIndex)
            let clampedLowerBound = max(lowerBound, document.blocks.startIndex)
            let clampedUpperBound = min(upperBound, document.blocks.index(before: document.blocks.endIndex))
            guard clampedLowerBound <= clampedUpperBound else { continue }

            for blockIndex in clampedLowerBound...clampedUpperBound {
                guard let blockID = blockIDsByIndex[blockIndex] else { continue }
                cursorsByBlockID[blockID, default: []].append(cursor)
            }
        }

        resolvedRemoteCursorsByBlockID = cursorsByBlockID
    }

    private func isRemotePageNewer(_ page: DocmostEditablePage) -> Bool {
        guard let remoteUpdatedAt = page.updatedAt else { return false }
        guard let lastRemoteUpdatedAt else { return true }
        return remoteUpdatedAt > lastRemoteUpdatedAt
    }

    private func isCRDTPageUpdateNewer(_ updatedAt: Date?) -> Bool {
        guard let updatedAt else { return true }
        guard let lastRemoteUpdatedAt else { return true }
        return updatedAt > lastRemoteUpdatedAt
    }

    private func applyRemotePageSnapshot(_ page: DocmostEditablePage, lastUpdatedBy: DocmostPagePerson?) {
        title = page.title
        document = NativeEditorDocument(proseMirrorDocument: page.content ?? ProseMirrorDocument())
        lastSavedTitle = title
        lastSavedDocument = document
        applyPagePermissions(page.permissions)
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

    private func recordRecentEditor(from person: DocmostPagePerson?) {
        guard let person else { return }
        activeCollaborators.removeAll { $0.source == .recentEditor }
        activeCollaborators.append(NativeEditorCollaborator(person: person))
    }

    private func applyCRDTBackedRemoteTitle(
        _ remoteTitle: String,
        updatedAt: Date?,
        lastUpdatedBy: DocmostPagePerson?
    ) {
        let hasLocalTitleEdits = title != lastSavedTitle

        if hasLocalTitleEdits {
            if remoteTitle == title {
                lastSavedTitle = remoteTitle
                rebaseEditingHistoryTitle(to: remoteTitle)
            } else if remoteTitle != lastSavedTitle {
                pendingRemotePage = nil
                pendingRemoteUpdate = NativeEditorRemoteUpdate(
                    updatedAt: updatedAt,
                    title: remoteTitle,
                    lastUpdatedBy: lastUpdatedBy
                )
                realtimeStatus = .conflict
                return
            }
        } else {
            applyRemoteTitle(remoteTitle)
            lastSavedTitle = remoteTitle
            rebaseEditingHistoryTitle(to: remoteTitle)
        }

        markRemoteBaseline(updatedAt: updatedAt ?? lastRemoteUpdatedAt)
        recalculateDirty()
    }

    private func applyPendingRemoteTitleUpdate(_ update: NativeEditorRemoteUpdate) {
        applyRemoteTitle(update.title)
        lastSavedTitle = update.title
        rebaseEditingHistoryTitle(to: update.title)
        pendingRemoteUpdate = nil
        markRemoteBaseline(updatedAt: update.updatedAt ?? lastRemoteUpdatedAt)
        recalculateDirty()
    }

    private func applyRemoteTitle(_ remoteTitle: String) {
        guard title != remoteTitle else { return }

        isApplyingHistory = true
        title = remoteTitle
        isApplyingHistory = false
    }

    private func rebaseEditingHistoryTitle(to title: String) {
        lastKnownSnapshot?.title = title

        for index in undoStack.indices {
            undoStack[index].title = title
        }

        for index in redoStack.indices {
            redoStack[index].title = title
        }
    }
}
