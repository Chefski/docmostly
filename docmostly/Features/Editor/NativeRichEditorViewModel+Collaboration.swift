import Foundation

// swiftlint:disable file_length

extension NativeRichEditorViewModel {
    func markRemoteBaseline(updatedAt: Date?) {
        self.updatedAt = updatedAt ?? self.updatedAt
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
        if let pendingRemoteCRDTSnapshot {
            applyPendingRemoteCRDTSnapshot(pendingRemoteCRDTSnapshot)
            return
        }

        if let pendingRemotePage {
            applyRemotePageSnapshot(pendingRemotePage, lastUpdatedBy: pendingRemoteUpdate?.lastUpdatedBy)
            return
        }

        guard let pendingRemoteUpdate else { return }
        applyPendingRemoteTitleUpdate(pendingRemoteUpdate)
    }

    @discardableResult
    func acceptPendingRemoteUpdate(
        matching expectedSnapshot: NativeEditorCRDTDocumentSnapshot,
        remoteUpdate expectedRemoteUpdate: NativeEditorRemoteUpdate?
    ) -> Bool {
        guard pendingRemoteCRDTSnapshot == expectedSnapshot,
              pendingRemoteUpdate == expectedRemoteUpdate else {
            return false
        }
        acceptPendingRemoteUpdate()
        return true
    }

    func rejectPendingRemoteUpdate() {
        let rejectedDeferredCRDTSnapshot = pendingRemoteCRDTSnapshot
        let rejectedRemoteTitle = pendingRemoteUpdate?.title ??
            rejectedDeferredCRDTSnapshot?.title ??
            title
        let rejectedRemoteUpdatedAt = rejectedDeferredCRDTSnapshot?.updatedAt ??
            pendingRemoteUpdate?.updatedAt ??
            lastRemoteUpdatedAt
        pendingRemotePage = nil
        pendingRemoteUpdate = nil
        pendingRemoteCRDTSnapshot = nil
        hasDurablyPersistedLocalCRDTDraft = false
        realtimeStatus = .connected

        if let rejectedDeferredCRDTSnapshot {
            lastSavedTitle = rejectedRemoteTitle
            lastSavedDocument = rejectedDeferredCRDTSnapshot.document
            markRemoteBaseline(updatedAt: rejectedRemoteUpdatedAt)
            isDirty = true
            lastKnownSnapshot = makeHistorySnapshot()
            publishKeptLocalDraft(
                over: rejectedDeferredCRDTSnapshot,
                remoteTitle: rejectedRemoteTitle
            )
        }
    }

    @discardableResult
    func rejectPendingRemoteUpdate(
        matching expectedSnapshot: NativeEditorCRDTDocumentSnapshot,
        remoteUpdate expectedRemoteUpdate: NativeEditorRemoteUpdate?
    ) -> Bool {
        guard pendingRemoteCRDTSnapshot == expectedSnapshot,
              pendingRemoteUpdate == expectedRemoteUpdate else {
            return false
        }
        rejectPendingRemoteUpdate()
        return true
    }

    func clearCollaborationPresence() {
        let retainedCollaborators = activeCollaborators.filter { $0.source != .presence }
        if activeCollaborators != retainedCollaborators {
            activeCollaborators = retainedCollaborators
        }
        if remoteCursors.isEmpty == false {
            remoteCursors = []
        }
        if resolvedRemoteCursors.isEmpty == false {
            resolvedRemoteCursors = []
        }
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

        if let pendingRemoteCRDTSnapshot {
            let pendingUpdate = pendingRemoteUpdate
            self.pendingRemoteUpdate = NativeEditorRemoteUpdate(
                updatedAt: updatedAt ?? pendingUpdate?.updatedAt ?? pendingRemoteCRDTSnapshot.updatedAt,
                title: remoteTitle ?? pendingUpdate?.title ?? pendingRemoteCRDTSnapshot.title ?? title,
                lastUpdatedBy: lastUpdatedBy ?? pendingUpdate?.lastUpdatedBy
            )
            realtimeStatus = .conflict
            return true
        }

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
        guard isCRDTEngineReadyForLocalChanges else {
            applyInitialCRDTDocumentSnapshot(snapshot)
            return
        }

        guard isDirty else {
            applyCleanCRDTDocumentSnapshot(snapshot)
            return
        }

        let hasEarlierDeferredConflict = pendingRemotePage != nil ||
            pendingRemoteUpdate != nil ||
            pendingRemoteCRDTSnapshot != nil ||
            realtimeStatus == .conflict
        let titleMatches = snapshot.title == nil || snapshot.title == title
        let documentMatches = snapshot.document.proseMirrorDocument.isCollaborationEquivalent(
            to: document.proseMirrorDocument
        )

        if hasEarlierDeferredConflict == false, titleMatches, documentMatches {
            pendingRemotePage = nil
            pendingRemoteUpdate = nil
            pendingRemoteCRDTSnapshot = nil
            hasDurablyPersistedLocalCRDTDraft = false
            markRemoteBaseline(updatedAt: snapshot.updatedAt ?? lastRemoteUpdatedAt)
            lastKnownSnapshot = makeHistorySnapshot()
            isDirty = true
            return
        }

        deferCRDTDocumentSnapshot(snapshot)
    }

    @discardableResult
    func applyAwarenessStates(_ states: [NativeEditorAwarenessState], localClientID: Int) -> Bool {
        let nextActiveCollaborators = activeCollaborators(from: states, localClientID: localClientID)
        if activeCollaborators != nextActiveCollaborators {
            activeCollaborators = nextActiveCollaborators
        }

        let remoteCursorsChanged = applyRemoteCursorsIfNeeded(
            remoteCursors(from: states, localClientID: localClientID)
        )
        markConnectedAfterAwarenessIfNeeded()
        return remoteCursorsChanged
    }

    private func activeCollaborators(
        from states: [NativeEditorAwarenessState],
        localClientID: Int
    ) -> [NativeEditorCollaborator] {
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
        return presenceCollaborators + recentEditors
    }

    private func remoteCursors(
        from states: [NativeEditorAwarenessState],
        localClientID: Int
    ) -> [NativeEditorRemoteCursor] {
        var seenCursorIDs: Set<String> = []
        return states.compactMap { state in
            guard state.clientID != localClientID else { return nil }
            guard let remoteCursor = NativeEditorRemoteCursor(awarenessState: state) else { return nil }
            guard seenCursorIDs.insert(remoteCursor.id).inserted else { return nil }
            return remoteCursor
        }
    }

    private func applyRemoteCursorsIfNeeded(_ nextRemoteCursors: [NativeEditorRemoteCursor]) -> Bool {
        let remoteCursorsChanged = remoteCursors != nextRemoteCursors
        if remoteCursorsChanged {
            remoteCursors = nextRemoteCursors
            if resolvedRemoteCursors.isEmpty == false {
                resolvedRemoteCursors = []
            }
        }
        return remoteCursorsChanged
    }

    private func markConnectedAfterAwarenessIfNeeded() {
        switch realtimeStatus {
        case .conflict, .authenticationFailed, .failed:
            break
        case .connected:
            break
        case .connecting, .disconnected:
            realtimeStatus = .connected
        }
    }

    func configureCRDTDocumentEngine(
        _ engine: any NativeEditorCRDTDocumentEngine,
        restoredLocalState: Bool = false
    ) {
        crdtDocumentEngine = engine
        crdtSyncCoordinator = makeCRDTSyncCoordinator(for: engine)
        isCRDTEngineReadyForLocalChanges = restoredLocalState || engine.requiresInitialRemoteSnapshot == false
    }

    func persistCurrentCRDTState(appState: AppState) async {
        await waitForStableCRDTLocalChangeBarrier()
        guard let crdtDocumentEngine else { return }

        do {
            let update = try await crdtDocumentEngine.encodeDocumentState()
            try await appState.persistCRDTStateUpdate(pageID: currentPageID, update: update)
        } catch is CancellationError {
            return
        } catch {
            appState.statusMessage = "Could not cache the collaborative document: " + error.localizedDescription
        }
    }

    func makeCRDTSyncCoordinator(
        for engine: any NativeEditorCRDTDocumentEngine
    ) -> NativeEditorCRDTSyncCoordinator {
        NativeEditorCRDTSyncCoordinator(
            documentEngine: engine,
            remoteUpdateHandler: { [weak self] update in
                guard let self else { return }
                try await self.applyOrderedCRDTRemoteUpdate(update)
            }
        )
    }

    private func applyOrderedCRDTRemoteUpdate(_ update: Data) async throws {
        await waitForStableCRDTLocalChangeBarrier()
        try Task.checkCancellation()
        guard let crdtDocumentEngine else { return }

        let snapshot: NativeEditorCRDTDocumentSnapshot?
        if let javaScriptEngine = crdtDocumentEngine as? NativeEditorJSCRDTDocumentEngine {
            snapshot = try javaScriptEngine.applyRemoteUpdateAndCaptureSnapshotSynchronously(update)
        } else {
            snapshot = try await crdtDocumentEngine.applyRemoteUpdateCapturingSnapshot(update)
        }

        guard let snapshot else { return }
        applyCRDTDocumentSnapshot(snapshot)
        await refreshResolvedRemoteCursors()
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

    func collaborationSession(
        participation: NativeEditorCollaborationParticipation = .interactive
    ) -> NativeEditorCollaborationSession {
        let collaborationDocument = NativeEditorCollaborationDocument(pageID: currentPageID)
        let syncDriver = crdtSyncCoordinator.map { coordinator in
            NativeEditorCollaborationSyncDriver(
                documentName: collaborationDocument.name,
                coordinator: coordinator
            )
        }
        let localAwarenessCursor: (@Sendable () async -> NativeEditorAwarenessCursor?)?
        let localAwarenessUpdates: AsyncStream<Void>?
        if participation.allowsLocalAwarenessUpdates {
            localAwarenessCursor = { [weak self] in
                await self?.localAwarenessCursor()
            }
            localAwarenessUpdates = self.localAwarenessUpdates()
        } else {
            localAwarenessCursor = nil
            localAwarenessUpdates = nil
        }

        return NativeEditorCollaborationSession(
            document: collaborationDocument,
            participation: participation,
            syncDriver: syncDriver,
            localAwarenessCursor: localAwarenessCursor,
            localAwarenessUpdates: localAwarenessUpdates
        )
    }

    func refreshResolvedRemoteCursors() async {
        guard let crdtDocumentEngine else {
            if resolvedRemoteCursors.isEmpty == false {
                resolvedRemoteCursors = []
            }
            return
        }

        var resolvedCursors: [NativeEditorResolvedRemoteCursor] = []
        resolvedCursors.reserveCapacity(remoteCursors.count)

        for cursor in remoteCursors {
            if let resolvedCursor = try? await crdtDocumentEngine.resolveRemoteCursor(cursor) {
                resolvedCursors.append(resolvedCursor)
            }
        }

        if resolvedRemoteCursors != resolvedCursors {
            resolvedRemoteCursors = resolvedCursors
        }
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
        remotePresenceProjection = NativeEditorRemotePresenceProjection(
            document: document,
            cursors: resolvedRemoteCursors
        )

        guard resolvedRemoteCursors.isEmpty == false, document.blocks.isEmpty == false else {
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

    func rootBlockID(forCollaboratorID collaboratorID: String) -> UUID? {
        guard
            let blockIndex = remotePresenceProjection.rootBlockIndex(for: collaboratorID),
            document.blocks.indices.contains(blockIndex)
        else {
            return nil
        }
        return document.blocks[blockIndex].id
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

    private func applyInitialCRDTDocumentSnapshot(_ snapshot: NativeEditorCRDTDocumentSnapshot) {
        isCRDTEngineReadyForLocalChanges = true

        guard isDirty else {
            applyCleanCRDTDocumentSnapshot(snapshot)
            return
        }

        let snapshotMatchesRESTBaseline = (snapshot.title == nil || snapshot.title == lastSavedTitle) &&
            snapshot.document.proseMirrorDocument.isCollaborationEquivalent(
                to: lastSavedDocument.proseMirrorDocument
            )
        let snapshotMatchesCurrentDraft = (snapshot.title == nil || snapshot.title == title) &&
            snapshot.document.proseMirrorDocument.isCollaborationEquivalent(
                to: document.proseMirrorDocument
            )

        if snapshotMatchesRESTBaseline {
            pendingRemotePage = nil
            pendingRemoteUpdate = nil
            pendingRemoteCRDTSnapshot = nil
            hasDurablyPersistedLocalCRDTDraft = false
            markRemoteBaseline(updatedAt: snapshot.updatedAt ?? lastRemoteUpdatedAt)
            lastKnownSnapshot = makeHistorySnapshot()
            isDirty = true
            publishKeptLocalDraft(
                over: snapshot,
                remoteTitle: snapshot.title ?? lastSavedTitle
            )
            return
        }

        if snapshotMatchesCurrentDraft {
            pendingRemotePage = nil
            pendingRemoteUpdate = nil
            pendingRemoteCRDTSnapshot = nil
            hasDurablyPersistedLocalCRDTDraft = false
            markRemoteBaseline(updatedAt: snapshot.updatedAt ?? lastRemoteUpdatedAt)
            lastKnownSnapshot = makeHistorySnapshot()
            isDirty = true
            recordCRDTProjectionReadyForAutosave()
            return
        }

        deferCRDTDocumentSnapshot(snapshot)
    }

    private func applyCleanCRDTDocumentSnapshot(_ snapshot: NativeEditorCRDTDocumentSnapshot) {
        if let snapshotTitle = snapshot.title {
            title = snapshotTitle
        }
        document = snapshot.document
        lastSavedTitle = title
        lastSavedDocument = document
        pendingRemotePage = nil
        pendingRemoteUpdate = nil
        pendingRemoteCRDTSnapshot = nil
        hasDurablyPersistedLocalCRDTDraft = false
        retainedReadOnlyDraftSnapshot = nil
        resolvedRemoteCursors = []
        markRemoteBaseline(updatedAt: snapshot.updatedAt ?? lastRemoteUpdatedAt)
        resetEditingHistory()
        isDirty = false
    }

    private func deferCRDTDocumentSnapshot(_ snapshot: NativeEditorCRDTDocumentSnapshot) {
        let pendingUpdate = pendingRemoteUpdate
        pendingRemotePage = nil
        pendingRemoteCRDTSnapshot = snapshot
        hasDurablyPersistedLocalCRDTDraft = false
        pendingRemoteUpdate = NativeEditorRemoteUpdate(
            updatedAt: snapshot.updatedAt ?? pendingUpdate?.updatedAt,
            title: snapshot.title ?? pendingUpdate?.title ?? title,
            lastUpdatedBy: pendingUpdate?.lastUpdatedBy
        )
        realtimeStatus = .conflict
    }

    private func applyPendingRemoteCRDTSnapshot(_ snapshot: NativeEditorCRDTDocumentSnapshot) {
        let pendingUpdate = pendingRemoteUpdate
        crdtLocalChangeTask?.cancel()
        crdtLocalChangeTask = nil

        isApplyingHistory = true
        title = pendingUpdate?.title ?? snapshot.title ?? title
        document = snapshot.document
        clearAuthoringState()
        isApplyingHistory = false

        lastSavedTitle = title
        lastSavedDocument = document
        pendingRemotePage = nil
        pendingRemoteUpdate = nil
        pendingRemoteCRDTSnapshot = nil
        hasDurablyPersistedLocalCRDTDraft = false
        retainedReadOnlyDraftSnapshot = nil
        resolvedRemoteCursors = []
        markRemoteBaseline(
            updatedAt: snapshot.updatedAt ?? pendingUpdate?.updatedAt ?? lastRemoteUpdatedAt
        )
        resetEditingHistory()
        isDirty = false
        notifyLocalAwarenessChanged()
    }

    private func applyRemotePageSnapshot(_ page: DocmostEditablePage, lastUpdatedBy: DocmostPagePerson?) {
        title = page.title
        document = NativeEditorDocument(proseMirrorDocument: page.content ?? ProseMirrorDocument())
        lastSavedTitle = title
        lastSavedDocument = document
        pendingRemoteCRDTSnapshot = nil
        hasDurablyPersistedLocalCRDTDraft = false
        retainedReadOnlyDraftSnapshot = nil
        applyPageDetails(page, fallbackLastUpdatedBy: lastUpdatedBy)
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
        lastUpdatedBy = person
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
        pendingRemoteCRDTSnapshot = nil
        hasDurablyPersistedLocalCRDTDraft = false
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
