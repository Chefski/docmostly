import Foundation

extension NativeRichEditorViewModel {
    func resetEditingHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        lastKnownSnapshot = makeHistorySnapshot()
        updateHistoryAvailability()
    }

    func handleDocumentChanged() {
        commitExternalChange(applyingInputRules: true)
    }

    func handleTitleChanged() {
        commitExternalChange(applyingInputRules: false)
    }

    func undo() {
        guard let previousSnapshot = undoStack.popLast() else { return }
        let currentSnapshot = makeHistorySnapshot()
        redoStack.append(currentSnapshot)
        applyHistorySnapshot(previousSnapshot)
    }

    func redo() {
        guard let nextSnapshot = redoStack.popLast() else { return }
        let currentSnapshot = makeHistorySnapshot()
        undoStack.append(currentSnapshot)
        applyHistorySnapshot(nextSnapshot)
    }

    func performUndoableEdit(_ edit: () -> Void) {
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
            recalculateDirty()
            return
        }

        guard makeHistorySnapshot() != before else {
            recalculateDirty()
            return
        }

        if applyingInputRules {
            applyMarkdownInputRuleIfNeeded()
            applySmartTypographyIfNeeded()
        }

        let after = makeHistorySnapshot()
        appendUndoSnapshot(before)
        redoStack.removeAll()
        lastKnownSnapshot = after
        updateHistoryAvailability()
        recalculateDirty()
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
    }

    private func updateHistoryAvailability() {
        canUndo = undoStack.isEmpty == false
        canRedo = redoStack.isEmpty == false
    }

    func waitForPendingCRDTLocalChange() async {
        await crdtLocalChangeTask?.value
    }

    private func queueCRDTLocalChange(
        before: NativeEditorHistorySnapshot,
        after: NativeEditorHistorySnapshot
    ) {
        guard let crdtDocumentEngine else { return }

        let previousTask = crdtLocalChangeTask
        let change = NativeEditorCRDTLocalChange(before: before, after: after)
        crdtLocalChangeTask = Task { [weak self, crdtDocumentEngine, change, previousTask] in
            await previousTask?.value
            guard Task.isCancelled == false else { return }

            do {
                try await crdtDocumentEngine.integrateLocalChange(change)
            } catch is CancellationError {
                return
            } catch {
                self?.realtimeStatus = .failed(error.localizedDescription)
            }
        }
    }
}
