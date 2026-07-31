import Foundation

nonisolated enum NativeEditorBlockRowPolicy {
    static func showsEditableTextEditor(block: NativeEditorBlock, isReadOnly: Bool) -> Bool {
        block.isEditable && isReadOnly == false
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
