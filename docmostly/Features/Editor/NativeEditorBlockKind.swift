import SwiftUI

enum NativeEditorBlockKind: Equatable, Sendable {
    case paragraph
    case heading(level: Int)
    case bulletListItem
    case orderedListItem(ordinal: Int)
    case taskListItem(isChecked: Bool)
    case blockquote
    case codeBlock(language: String?)
    case table(NativeEditorTable)
    case image(NativeEditorMediaBlock)
    case video(NativeEditorMediaBlock)
    case audio(NativeEditorMediaBlock)
    case pdf(NativeEditorPDFBlock)
    case attachment(NativeEditorAttachmentBlock)
    case callout(NativeEditorCalloutBlock)
    case details(NativeEditorDetailsBlock)
    case pageBreak
    case divider
    case columns(NativeEditorColumnsBlock)
    case subpages
    case transclusionSource(NativeEditorTransclusionSourceBlock)
    case transclusionReference(NativeEditorTransclusionReferenceBlock)
    case embed(NativeEditorEmbedBlock)
    case drawio(NativeEditorDiagramBlock)
    case excalidraw(NativeEditorDiagramBlock)
    case mathBlock(NativeEditorMathBlock)
    case unsupported(type: String)

    var isEditable: Bool {
        switch self {
        case .paragraph, .heading, .bulletListItem, .orderedListItem, .taskListItem, .blockquote, .codeBlock:
            return true
        case .table, .image, .video, .audio, .pdf, .attachment, .callout, .details, .pageBreak, .divider,
                .columns, .subpages, .transclusionSource, .transclusionReference, .embed, .drawio, .excalidraw,
                .mathBlock, .unsupported:
            return false
        }
    }

    var editorFont: Font {
        switch self {
        case .heading(let level):
            level == 1 ? .title : .title2
        case .codeBlock:
            .body.monospaced()
        case .paragraph, .bulletListItem, .orderedListItem, .taskListItem, .blockquote:
            .body
        case .table, .image, .video, .audio, .pdf, .attachment, .callout, .details, .pageBreak, .divider,
                .columns, .subpages, .transclusionSource, .transclusionReference, .embed, .drawio, .excalidraw,
                .mathBlock, .unsupported:
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
        case .table:
            "Table"
        case .image:
            "Image"
        case .video:
            "Video"
        case .audio:
            "Audio"
        case .pdf:
            "PDF"
        case .attachment:
            "File attachment"
        case .callout(let callout):
            "\(callout.style.capitalized) callout"
        case .details:
            "Toggle block"
        case .pageBreak:
            "Page break"
        case .divider:
            "Divider"
        case .columns:
            "Columns"
        case .subpages:
            "Subpages"
        case .transclusionSource:
            "Synced block"
        case .transclusionReference:
            "Synced block reference"
        case .embed(let embed):
            embed.provider.map { "\($0) embed" } ?? "Embed"
        case .drawio:
            "Draw.io diagram"
        case .excalidraw:
            "Excalidraw diagram"
        case .mathBlock:
            "Math equation"
        case .unsupported(let type):
            "Unsupported \(type) block"
        }
    }
}
