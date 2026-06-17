import SwiftUI

enum NativeEditorBlockKind: Equatable, Sendable {
    case paragraph
    case heading(level: Int)
    case bulletListItem
    case orderedListItem(ordinal: Int)
    case taskListItem(isChecked: Bool)
    case blockquote
    case codeBlock(language: String?)
    case unsupported(type: String)

    var isEditable: Bool {
        if case .unsupported = self {
            return false
        }
        return true
    }

    var editorFont: Font {
        switch self {
        case .heading(let level):
            level == 1 ? .title : .title2
        case .codeBlock:
            .body.monospaced()
        default:
            .body
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .paragraph:
            "Paragraph"
        case .heading(let level):
            "Heading \(level)"
        case .bulletListItem:
            "Bulleted list item"
        case .orderedListItem(let ordinal):
            "Numbered list item \(ordinal)"
        case .taskListItem:
            "Task list item"
        case .blockquote:
            "Quote"
        case .codeBlock:
            "Code block"
        case .unsupported(let type):
            "Unsupported \(type) block"
        }
    }
}
