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
    case table
    case callout
    case details
    case pageBreak
    case divider
    case columns
    case subpages
    case syncedBlock
    case embed
    case mathBlock
    case mermaid

    var id: String { rawValue }

    static let primaryCases: [NativeEditorCommand] = [
        .paragraph,
        .heading1,
        .heading2,
        .bulletedList,
        .numberedList,
        .todoList,
        .quote,
        .codeBlock
    ]

    static let richCases: [NativeEditorCommand] = [
        .table,
        .callout,
        .details,
        .pageBreak,
        .divider,
        .columns,
        .subpages,
        .syncedBlock,
        .embed,
        .mathBlock,
        .mermaid
    ]

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
        case .table:
            "Table"
        case .callout:
            "Callout"
        case .details:
            "Details"
        case .pageBreak:
            "Page Break"
        case .divider:
            "Divider"
        case .columns:
            "Columns"
        case .subpages:
            "Subpages"
        case .syncedBlock:
            "Synced Block"
        case .embed:
            "Embed"
        case .mathBlock:
            "Math Block"
        case .mermaid:
            "Mermaid"
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
        case .table:
            "Two-column table"
        case .callout:
            "Highlighted note"
        case .details:
            "Collapsible detail section"
        case .pageBreak:
            "Print page break"
        case .divider:
            "Horizontal divider"
        case .columns:
            "Two-column layout"
        case .subpages:
            "Child page list"
        case .syncedBlock:
            "Reusable synced content"
        case .embed:
            "External URL embed"
        case .mathBlock:
            "Display equation"
        case .mermaid:
            "Mermaid diagram code"
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
        case .table:
            "tablecells"
        case .callout:
            "lightbulb"
        case .details:
            "chevron.right.circle"
        case .pageBreak:
            "doc.text"
        case .divider:
            "minus"
        case .columns:
            "square.split.2x1"
        case .subpages:
            "doc.on.doc"
        case .syncedBlock:
            "arrow.triangle.2.circlepath"
        case .embed:
            "link.badge.plus"
        case .mathBlock:
            "function"
        case .mermaid:
            "point.3.connected.trianglepath.dotted"
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
        case .table:
            .table(NativeEditorTable(rows: defaultTableRows))
        case .callout:
            .callout(NativeEditorCalloutBlock(style: "info", icon: "lightbulb", previewText: "Callout"))
        case .details:
            .details(NativeEditorDetailsBlock(summary: "Details", previewText: "Details", isOpen: true))
        case .pageBreak:
            .pageBreak
        case .divider:
            .divider
        case .columns:
            .columns(NativeEditorColumnsBlock(
                layout: "two_equal",
                widthMode: "wide",
                columnCount: 2,
                previewText: "Left Right"
            ))
        case .subpages:
            .subpages
        case .syncedBlock:
            .transclusionSource(NativeEditorTransclusionSourceBlock(
                identifier: "sync",
                previewText: "Synced block"
            ))
        case .embed:
            .embed(NativeEditorEmbedBlock(
                source: "https://example.com",
                provider: "Embed",
                alignment: nil,
                width: nil,
                height: nil
            ))
        case .mathBlock:
            .mathBlock(NativeEditorMathBlock(text: "E = mc^2"))
        case .mermaid:
            .codeBlock(language: "mermaid")
        }
    }

    func matches(query: String) -> Bool {
        guard query.isEmpty == false else { return true }

        return title.localizedStandardContains(query) ||
            subtitle.localizedStandardContains(query) ||
            rawValue.localizedStandardContains(query)
    }
}
