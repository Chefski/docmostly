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

        appendUndoSnapshot(before)
        redoStack.removeAll()
        lastKnownSnapshot = makeHistorySnapshot()
        updateHistoryAvailability()
        recalculateDirty()
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
}
