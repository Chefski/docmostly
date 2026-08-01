import Foundation

nonisolated struct NativeEditorInlineTypingContext: Equatable, Sendable {
    let blockID: UUID
    var marks: Set<NativeEditorInlineMark>
}
