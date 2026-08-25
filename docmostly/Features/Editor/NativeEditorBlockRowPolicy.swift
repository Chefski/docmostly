import Foundation

nonisolated enum NativeEditorBlockRowPolicy {
    static func usesTextInputSurface(block: NativeEditorBlock) -> Bool {
        block.isEditable
    }

    static func allowsTaskToggle(isReadOnly: Bool) -> Bool {
        isReadOnly == false
    }

    static func hasVisiblePrefix(kind: NativeEditorBlockKind) -> Bool {
        switch kind {
        case .bulletListItem, .orderedListItem, .taskListItem, .unsupported:
            true
        default:
            false
        }
    }
}
