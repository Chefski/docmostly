import Foundation

extension NativeRichEditorViewModel {
    func resetEditingHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        lastKnownSnapshot = makeHistorySnapshot()
        updateHistoryAvailability()
    }

    func applyServerHistorySnapshot(title: String, document: ProseMirrorDocument) {
        guard canEdit else { return }

        isApplyingHistory = true
        self.title = title
        self.document = NativeEditorDocument(proseMirrorDocument: document)
        clearAuthoringState()
        isApplyingHistory = false
        resetEditingHistory()
        recalculateDirty()
        recordLocalEditForAutosave()
        notifyLocalAwarenessChanged()
    }

    func restoreEditingSnapshot(_ snapshot: NativeEditorHistorySnapshot) {
        applyHistorySnapshot(snapshot)
    }

    func handleDocumentChanged() {
        guard canEdit else {
            restoreRetainedReadOnlyDraft()
            return
        }

        commitExternalChange(applyingInputRules: true)
        notifyLocalAwarenessChanged()
    }

    func handleTitleChanged() {
        guard canEdit else {
            restoreRetainedReadOnlyDraft()
            return
        }

        commitExternalChange(applyingInputRules: false)
        notifyLocalAwarenessChanged()
    }

    func undo() {
        guard canEdit else { return }
        guard let previousSnapshot = undoStack.popLast() else { return }
        let currentSnapshot = makeHistorySnapshot()
        redoStack.append(currentSnapshot)
        applyHistorySnapshot(previousSnapshot)
        queueCRDTLocalChange(before: currentSnapshot, after: previousSnapshot)
        recordLocalEditForAutosave()
    }

    func redo() {
        guard canEdit else { return }
        guard let nextSnapshot = redoStack.popLast() else { return }
        let currentSnapshot = makeHistorySnapshot()
        undoStack.append(currentSnapshot)
        applyHistorySnapshot(nextSnapshot)
        queueCRDTLocalChange(before: currentSnapshot, after: nextSnapshot)
        recordLocalEditForAutosave()
    }

    func performUndoableEdit(_ edit: () -> Void) {
        guard canEdit else { return }

        let before = makeHistorySnapshot()
        edit()
        let after = makeHistorySnapshot()
        guard after != before else { return }

        appendUndoSnapshot(before)
        redoStack.removeAll()
        lastKnownSnapshot = after
        updateHistoryAvailability()
        recalculateDirty()
        queueCRDTLocalChange(before: before, after: after)
        recordLocalEditForAutosave()
        notifyLocalAwarenessChanged()
    }

    func makeHistorySnapshot() -> NativeEditorHistorySnapshot {
        NativeEditorHistorySnapshot(
            title: title,
            document: document,
            activeBlockID: activeBlockID,
            selectedBlockID: selectedBlockID,
            visibleBlockControlsID: visibleBlockControlsID,
            isTitleFocused: isTitleFocused
        )
    }

    private func commitExternalChange(applyingInputRules: Bool) {
        guard isApplyingHistory == false else { return }

        guard let before = lastKnownSnapshot else {
            lastKnownSnapshot = makeHistorySnapshot()
            isDirty = true
            recordLocalEditForAutosave()
            return
        }

        if applyingInputRules {
            applyMarkdownInputRuleIfNeeded()
            applySmartTypographyIfNeeded()
            applyInlineMarkdownInputRuleIfNeeded()
        }

        let after = makeHistorySnapshot()
        guard after != before else {
            recalculateDirty()
            return
        }

        appendUndoSnapshot(before)
        redoStack.removeAll()
        lastKnownSnapshot = after
        updateHistoryAvailability()
        isDirty = true
        queueCRDTLocalChange(before: before, after: after)
        recordLocalEditForAutosave()
    }

    private func appendUndoSnapshot(_ snapshot: NativeEditorHistorySnapshot) {
        if undoStack.last != snapshot {
            undoStack.append(snapshot)
        }

        if undoStack.count > 100 {
            undoStack.removeFirst(undoStack.count - 100)
        }
    }

    private func applyHistorySnapshot(_ snapshot: NativeEditorHistorySnapshot) {
        isApplyingHistory = true
        title = snapshot.title
        document = snapshot.document
        activeBlockID = snapshot.activeBlockID
        selectedBlockID = snapshot.selectedBlockID
        visibleBlockControlsID = snapshot.visibleBlockControlsID
        isTitleFocused = snapshot.isTitleFocused
        isApplyingHistory = false
        lastKnownSnapshot = snapshot
        updateHistoryAvailability()
        recalculateDirty()
        notifyLocalAwarenessChanged()
    }

    private func updateHistoryAvailability() {
        canUndo = undoStack.isEmpty == false
        canRedo = redoStack.isEmpty == false
    }

    private func recordLocalEditForAutosave() {
        localEditRevision += 1
        hasDurablyPersistedLocalCRDTDraft = false
    }

    func recordCRDTProjectionReadyForAutosave() {
        recordLocalEditForAutosave()
    }

    private func restoreRetainedReadOnlyDraft() {
        guard isApplyingHistory == false else { return }

        let retainedSnapshot = retainedReadOnlyDraftSnapshot
        title = retainedSnapshot?.title ?? lastSavedTitle
        document = retainedSnapshot?.document ?? lastSavedDocument
        clearAuthoringState()
        lastKnownSnapshot = makeHistorySnapshot()
        recalculateDirty()
        updateHistoryAvailability()
    }

    func waitForPendingCRDTLocalChange() async throws {
        try await crdtLocalChangeTask?.value
    }

    func waitForStableCRDTLocalChangeBarrier() async {
        var stableGeneration = crdtOperationGeneration

        while Task.isCancelled == false {
            do {
                try await crdtLocalChangeTask?.value
            } catch {
                return
            }

            guard stableGeneration != crdtOperationGeneration else { return }
            stableGeneration = crdtOperationGeneration
        }
    }

    func enqueueCRDTSnapshotFlush(
        title: String,
        document: NativeEditorDocument
    ) -> Task<NativeEditorCRDTSaveResult, any Error>? {
        guard canEdit else { return nil }
        guard isCRDTEngineReadyForLocalChanges else { return nil }
        guard let crdtSyncCoordinator else { return nil }

        crdtOperationGeneration += 1
        let previousTask = crdtLocalChangeTask
        let flushTask = Task { [crdtSyncCoordinator, previousTask] in
            try await previousTask?.value
            try Task.checkCancellation()
            return try await crdtSyncCoordinator.flushPendingLocalChanges(
                title: title,
                document: document
            )
        }
        crdtLocalChangeTask = Task { [flushTask] in
            _ = try await flushTask.value
        }
        return flushTask
    }

    private func queueCRDTLocalChange(
        before: NativeEditorHistorySnapshot,
        after: NativeEditorHistorySnapshot
    ) {
        guard canEdit else { return }
        guard isCRDTEngineReadyForLocalChanges else { return }
        guard pendingRemoteCRDTSnapshot == nil else { return }
        guard let crdtSyncCoordinator else { return }

        crdtOperationGeneration += 1
        let previousTask = crdtLocalChangeTask
        let change = NativeEditorCRDTLocalChange(before: before, after: after)
        crdtLocalChangeTask = Task { [weak self, crdtSyncCoordinator, change, previousTask] in
            do {
                try await previousTask?.value
            } catch is CancellationError {
                try Task.checkCancellation()
            } catch {
                // The latest full snapshot can repair a failed predecessor in the local chain.
            }
            try Task.checkCancellation()
            guard let self, self.pendingRemoteCRDTSnapshot == nil else { return }

            do {
                try await crdtSyncCoordinator.integrateLocalChange(change)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                realtimeStatus = .failed(error.localizedDescription)
                throw error
            }
        }
    }

    func publishKeptLocalDraft(
        over snapshot: NativeEditorCRDTDocumentSnapshot,
        remoteTitle: String
    ) {
        let remoteSnapshot = NativeEditorHistorySnapshot(
            title: remoteTitle,
            document: snapshot.document,
            activeBlockID: nil,
            selectedBlockID: nil,
            visibleBlockControlsID: nil,
            isTitleFocused: false
        )
        let localSnapshot = makeHistorySnapshot()
        queueCRDTLocalChange(before: remoteSnapshot, after: localSnapshot)
        recordLocalEditForAutosave()
        notifyLocalAwarenessChanged()
    }
}
