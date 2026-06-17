import Foundation

enum NativeEditorHighlightColorAttribute: CodableAttributedStringKey {
    typealias Value = String
    static let name = "docmostly.highlightColor"
}

enum NativeEditorHighlightColorNameAttribute: CodableAttributedStringKey {
    typealias Value = String
    static let name = "docmostly.highlightColorName"
}

enum NativeEditorTextColorAttribute: CodableAttributedStringKey {
    typealias Value = String
    static let name = "docmostly.textColor"
}

enum NativeEditorCommentIDAttribute: CodableAttributedStringKey {
    typealias Value = String
    static let name = "docmostly.commentID"
}

enum NativeEditorCommentResolvedAttribute: CodableAttributedStringKey {
    typealias Value = Bool
    static let name = "docmostly.commentResolved"
}

enum NativeEditorMentionAttribute: CodableAttributedStringKey {
    typealias Value = NativeEditorMention
    static let name = "docmostly.mention"
}

enum NativeEditorStatusAttribute: CodableAttributedStringKey {
    typealias Value = NativeEditorStatusBadge
    static let name = "docmostly.status"
}

enum NativeEditorMathInlineAttribute: CodableAttributedStringKey {
    typealias Value = NativeEditorMathInline
    static let name = "docmostly.mathInline"
}
