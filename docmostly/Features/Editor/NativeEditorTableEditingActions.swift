import Foundation

struct NativeEditorTableEditingActions {
    let updateCell: (UUID, Int, Int, String) -> Void
    let insertRowAbove: (UUID, Int) -> Void
    let insertRowBelow: (UUID, Int) -> Void
    let deleteRow: (UUID, Int) -> Void
    let insertColumnBefore: (UUID, Int) -> Void
    let insertColumnAfter: (UUID, Int) -> Void
    let deleteColumn: (UUID, Int) -> Void
    let updateColumnWidth: (UUID, Int, Int) -> Void
}
