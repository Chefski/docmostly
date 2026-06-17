import Foundation

struct NativeEditorTableEditingActions {
    let updateCell: (UUID, Int, Int, String) -> Void
    let insertRowBelow: (UUID, Int) -> Void
    let deleteRow: (UUID, Int) -> Void
    let insertColumnAfter: (UUID, Int) -> Void
    let deleteColumn: (UUID, Int) -> Void
}
