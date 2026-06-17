import Foundation
import SwiftUI

struct NativeEditorBlock: Identifiable, Equatable {
    let id: UUID
    var kind: NativeEditorBlockKind
    var text: AttributedString
    var alignment: NativeEditorTextAlignment
    var indentLevel: Int
    var selection: AttributedTextSelection
    var inlineContent: [NativeEditorInlineContent]?
    var rawNode: ProseMirrorNode?

    init(
        id: UUID = UUID(),
        kind: NativeEditorBlockKind,
        text: AttributedString,
        alignment: NativeEditorTextAlignment,
        indentLevel: Int = 0,
        selection: AttributedTextSelection = AttributedTextSelection(),
        inlineContent: [NativeEditorInlineContent]? = nil,
        rawNode: ProseMirrorNode? = nil
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.alignment = alignment
        self.indentLevel = indentLevel
        self.selection = selection
        self.inlineContent = inlineContent
        self.rawNode = rawNode
    }

    var isEditable: Bool {
        kind.isEditable && inlineContent == nil
    }

    static func == (lhs: NativeEditorBlock, rhs: NativeEditorBlock) -> Bool {
        lhs.id == rhs.id &&
            lhs.kind == rhs.kind &&
            lhs.text == rhs.text &&
            lhs.alignment == rhs.alignment &&
            lhs.indentLevel == rhs.indentLevel &&
            lhs.inlineContent == rhs.inlineContent &&
            lhs.rawNode == rhs.rawNode
    }
}
