import Foundation

struct NativeEditorHistorySnapshot: Equatable, Sendable {
    var title: String
    var document: NativeEditorDocument
    var activeBlockID: UUID?
    var selectedBlockID: UUID?
    var visibleBlockControlsID: UUID?
    var isTitleFocused: Bool
}
