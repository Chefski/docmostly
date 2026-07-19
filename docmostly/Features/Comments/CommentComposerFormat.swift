import SwiftUI

nonisolated enum CommentComposerFormat: String, CaseIterable, Identifiable, Sendable {
    case bold
    case italic
    case strikethrough
    case code

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bold:
            "Bold"
        case .italic:
            "Italic"
        case .strikethrough:
            "Strikethrough"
        case .code:
            "Inline Code"
        }
    }

    var systemImage: String {
        switch self {
        case .bold:
            "bold"
        case .italic:
            "italic"
        case .strikethrough:
            "strikethrough"
        case .code:
            "chevron.left.forwardslash.chevron.right"
        }
    }

    var presentationIntent: InlinePresentationIntent {
        switch self {
        case .bold:
            .stronglyEmphasized
        case .italic:
            .emphasized
        case .strikethrough:
            .strikethrough
        case .code:
            .code
        }
    }
}
