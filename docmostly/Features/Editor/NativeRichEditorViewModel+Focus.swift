import Foundation

extension NativeRichEditorViewModel {
    func textInputDidBeginEditing(blockID: UUID) {
        guard canEdit, document.blocks.contains(where: { $0.id == blockID && $0.isEditable }) else {
            clearAuthoringState()
            return
        }
        guard focusedTextInputBlockID != blockID || activeBlockID != blockID || isTitleFocused else { return }

        isTitleFocused = false
        activeBlockID = blockID
        focusedTextInputBlockID = blockID
        selectedBlockID = nil
        visibleBlockControlsID = nil
        notifyLocalAwarenessChanged()
    }

    func textInputDidEndEditing(blockID: UUID) {
        guard focusedTextInputBlockID == blockID else { return }

        focusedTextInputBlockID = nil
        guard activeBlockID == blockID else { return }
        activeBlockID = nil
        notifyLocalAwarenessChanged()
    }
}
