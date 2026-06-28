import Foundation

enum NativeEditorCommand: String, CaseIterable, Identifiable {
    case paragraph
    case heading1
    case heading2
    case heading3
    case bulletedList
    case numberedList
    case todoList
    case quote
    case codeBlock
    case image
    case video
    case audio
    case pdf
    case fileAttachment
    case table
    case baseInline
    case kanban
    case callout
    case details
    case mathInline
    case pageBreak
    case divider
    case columns
    case columns3
    case columns4
    case columns5
    case subpages
    case syncedBlock
    case embed
    case iframeEmbed
    case airtableEmbed
    case loomEmbed
    case figmaEmbed
    case typeformEmbed
    case miroEmbed
    case youtubeEmbed
    case vimeoEmbed
    case framerEmbed
    case googleDriveEmbed
    case googleSheetsEmbed
    case mathBlock
    case mermaid
    case drawio
    case excalidraw
    case date
    case time
    case status
    case emoji

    var id: String { rawValue }

    static let primaryCases: [NativeEditorCommand] = [
        .paragraph,
        .heading1,
        .heading2,
        .heading3,
        .bulletedList,
        .numberedList,
        .todoList,
        .quote,
        .codeBlock
    ]

    static let richCases: [NativeEditorCommand] = [
        .image,
        .video,
        .audio,
        .pdf,
        .fileAttachment,
        .table,
        .baseInline,
        .kanban,
        .callout,
        .details,
        .pageBreak,
        .divider,
        .columns,
        .columns3,
        .columns4,
        .columns5,
        .subpages,
        .syncedBlock,
        .embed,
        .iframeEmbed,
        .airtableEmbed,
        .loomEmbed,
        .figmaEmbed,
        .typeformEmbed,
        .miroEmbed,
        .youtubeEmbed,
        .vimeoEmbed,
        .framerEmbed,
        .googleDriveEmbed,
        .googleSheetsEmbed,
        .mathBlock,
        .mermaid,
        .drawio,
        .excalidraw
    ]

    var title: String {
        switch self {
        case .paragraph:
            "Paragraph"
        case .heading1:
            "Heading 1"
        case .heading2:
            "Heading 2"
        case .heading3:
            "Heading 3"
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
        case .image:
            "Image"
        case .video:
            "Video"
        case .audio:
            "Audio"
        case .pdf:
            "PDF"
        case .fileAttachment:
            "File"
        case .table:
            "Table"
        case .baseInline:
            "Base (Inline)"
        case .kanban:
            "Kanban"
        case .callout:
            "Callout"
        case .details:
            "Details"
        case .mathInline:
            "Math Inline"
        case .pageBreak:
            "Page Break"
        case .divider:
            "Divider"
        case .columns:
            "2 Columns"
        case .columns3:
            "3 Columns"
        case .columns4:
            "4 Columns"
        case .columns5:
            "5 Columns"
        case .subpages:
            "Subpages"
        case .syncedBlock:
            "Synced Block"
        case .embed:
            "Embed"
        case .iframeEmbed:
            "Iframe embed"
        case .airtableEmbed:
            "Airtable"
        case .loomEmbed:
            "Loom"
        case .figmaEmbed:
            "Figma"
        case .typeformEmbed:
            "Typeform"
        case .miroEmbed:
            "Miro"
        case .youtubeEmbed:
            "YouTube"
        case .vimeoEmbed:
            "Vimeo"
        case .framerEmbed:
            "Framer"
        case .googleDriveEmbed:
            "Google Drive"
        case .googleSheetsEmbed:
            "Google Sheets"
        case .mathBlock:
            "Math Block"
        case .mermaid:
            "Mermaid"
        case .drawio:
            "Draw.io"
        case .excalidraw:
            "Excalidraw"
        case .date:
            "Date"
        case .time:
            "Time"
        case .status:
            "Status"
        case .emoji:
            "Emoji"
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
        case .heading3:
            "Small section heading"
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
        case .image:
            "Image placeholder"
        case .video:
            "Video placeholder"
        case .audio:
            "Audio placeholder"
        case .pdf:
            "PDF placeholder"
        case .fileAttachment:
            "File attachment placeholder"
        case .table:
            "Two-column table"
        case .baseInline:
            "Inline base placeholder"
        case .kanban:
            "Kanban base placeholder"
        case .callout:
            "Highlighted note"
        case .details:
            "Collapsible detail section"
        case .mathInline:
            "Inline equation"
        case .pageBreak:
            "Print page break"
        case .divider:
            "Horizontal divider"
        case .columns:
            "Two-column layout"
        case .columns3:
            "Three-column layout"
        case .columns4:
            "Four-column layout"
        case .columns5:
            "Five-column layout"
        case .subpages:
            "Child page list"
        case .syncedBlock:
            "Reusable synced content"
        case .embed:
            "External URL embed"
        case .iframeEmbed:
            "Iframe embed"
        case .airtableEmbed:
            "Airtable embed"
        case .loomEmbed:
            "Loom video embed"
        case .figmaEmbed:
            "Figma file embed"
        case .typeformEmbed:
            "Typeform embed"
        case .miroEmbed:
            "Miro board embed"
        case .youtubeEmbed:
            "YouTube video embed"
        case .vimeoEmbed:
            "Vimeo video embed"
        case .framerEmbed:
            "Framer prototype embed"
        case .googleDriveEmbed:
            "Google Drive embed"
        case .googleSheetsEmbed:
            "Google Sheets embed"
        case .mathBlock:
            "Display equation"
        case .mermaid:
            "Mermaid diagram code"
        case .drawio:
            "Draw.io diagram"
        case .excalidraw:
            "Excalidraw whiteboard"
        case .date:
            "Insert current date"
        case .time:
            "Insert current time"
        case .status:
            "Inline status badge"
        case .emoji:
            "Start emoji entry"
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
        case .heading3:
            "h3"
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
        case .image:
            "photo"
        case .video:
            "play.rectangle"
        case .audio:
            "waveform"
        case .pdf:
            "doc.richtext"
        case .fileAttachment:
            "paperclip"
        case .table:
            "tablecells"
        case .baseInline:
            "tablecells.badge.ellipsis"
        case .kanban:
            "rectangle.3.group"
        case .callout:
            "lightbulb"
        case .details:
            "chevron.right.circle"
        case .mathInline:
            "x.squareroot"
        case .pageBreak:
            "doc.text"
        case .divider:
            "minus"
        case .columns:
            "square.split.2x1"
        case .columns3:
            "square.split.2x2"
        case .columns4:
            "square.grid.2x2"
        case .columns5:
            "square.grid.3x3"
        case .subpages:
            "doc.on.doc"
        case .syncedBlock:
            "arrow.triangle.2.circlepath"
        case .embed:
            "link.badge.plus"
        case .iframeEmbed:
            "appwindow"
        case .airtableEmbed:
            "tablecells"
        case .loomEmbed:
            "video"
        case .figmaEmbed:
            "paintpalette"
        case .typeformEmbed:
            "list.clipboard"
        case .miroEmbed:
            "rectangle.and.pencil.and.ellipsis"
        case .youtubeEmbed:
            "play.rectangle"
        case .vimeoEmbed:
            "video.badge.waveform"
        case .framerEmbed:
            "shippingbox"
        case .googleDriveEmbed:
            "externaldrive"
        case .googleSheetsEmbed:
            "tablecells"
        case .mathBlock:
            "function"
        case .mermaid:
            "point.3.connected.trianglepath.dotted"
        case .drawio:
            "flowchart"
        case .excalidraw:
            "scribble.variable"
        case .date:
            "calendar"
        case .time:
            "clock"
        case .status:
            "tag"
        case .emoji:
            "face.smiling"
        }
    }

}
