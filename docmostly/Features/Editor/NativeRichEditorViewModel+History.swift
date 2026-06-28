import Foundation

extension NativeRichEditorViewModel {
    func resetEditingHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        lastKnownSnapshot = makeHistorySnapshot()
        updateHistoryAvailability()
    }

    func handleDocumentChanged() {
        guard canEdit else {
            restoreReadOnlyBaseline()
            return
        }

        commitExternalChange(applyingInputRules: true)
        notifyLocalAwarenessChanged()
    }

    func handleTitleChanged() {
        guard canEdit else {
            restoreReadOnlyBaseline()
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
    }

    func redo() {
        guard canEdit else { return }
        guard let nextSnapshot = redoStack.popLast() else { return }
        let currentSnapshot = makeHistorySnapshot()
        undoStack.append(currentSnapshot)
        applyHistorySnapshot(nextSnapshot)
        queueCRDTLocalChange(before: currentSnapshot, after: nextSnapshot)
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

    private func restoreReadOnlyBaseline() {
        guard isApplyingHistory == false else { return }

        title = lastSavedTitle
        document = lastSavedDocument
        lastKnownSnapshot = makeHistorySnapshot()
        isDirty = false
        updateHistoryAvailability()
    }

    func waitForPendingCRDTLocalChange() async throws {
        try await crdtLocalChangeTask?.value
    }

    private func queueCRDTLocalChange(
        before: NativeEditorHistorySnapshot,
        after: NativeEditorHistorySnapshot
    ) {
        guard let crdtDocumentEngine else { return }

        let previousTask = crdtLocalChangeTask
        let change = NativeEditorCRDTLocalChange(before: before, after: after)
        crdtLocalChangeTask = Task { [weak self, crdtDocumentEngine, change, previousTask] in
            try await previousTask?.value
            try Task.checkCancellation()

            do {
                try await crdtDocumentEngine.integrateLocalChange(change)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                self?.realtimeStatus = .failed(error.localizedDescription)
                throw error
            }
        }
    }
}
