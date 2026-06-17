import Foundation

enum NativeEditorCommand: String, CaseIterable, Identifiable {
    case paragraph
    case heading1
    case heading2
    case bulletedList
    case numberedList
    case todoList
    case quote
    case codeBlock

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paragraph:
            "Paragraph"
        case .heading1:
            "Heading 1"
        case .heading2:
            "Heading 2"
        case .bulletedList:
            "Bulleted List"
        case .numberedList:
            "Numbered List"
        case .todoList:
            "To-do List"
        case .quote:
            "Quote"
        case .codeBlock:
            "Code Block"
        }
    }

    var subtitle: String {
        switch self {
        case .paragraph:
            "Plain page text"
        case .heading1:
            "Large section heading"
        case .heading2:
            "Medium section heading"
        case .bulletedList:
            "Simple unordered list"
        case .numberedList:
            "Ordered steps"
        case .todoList:
            "Checklist item"
        case .quote:
            "Quoted callout"
        case .codeBlock:
            "Preformatted code"
        }
    }

    var systemImage: String {
        switch self {
        case .paragraph:
            "paragraphsign"
        case .heading1:
            "h1"
        case .heading2:
            "h2"
        case .bulletedList:
            "list.bullet"
        case .numberedList:
            "list.number"
        case .todoList:
            "checklist"
        case .quote:
            "quote.opening"
        case .codeBlock:
            "curlybraces"
        }
    }

    var blockKind: NativeEditorBlockKind {
        switch self {
        case .paragraph:
            .paragraph
        case .heading1:
            .heading(level: 1)
        case .heading2:
            .heading(level: 2)
        case .bulletedList:
            .bulletListItem
        case .numberedList:
            .orderedListItem(ordinal: 1)
        case .todoList:
            .taskListItem(isChecked: false)
        case .quote:
            .blockquote
        case .codeBlock:
            .codeBlock(language: nil)
        }
    }

    func matches(query: String) -> Bool {
        guard query.isEmpty == false else { return true }

        return title.localizedStandardContains(query) ||
            subtitle.localizedStandardContains(query) ||
            rawValue.localizedStandardContains(query)
    }
}
