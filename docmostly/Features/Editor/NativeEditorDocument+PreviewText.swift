import Foundation

nonisolated extension NativeEditorDocument {
    static func previewText(for kind: NativeEditorBlockKind) -> String {
        if let mediaPreviewText = mediaPreviewText(for: kind) {
            return mediaPreviewText
        }

        if let structuralPreviewText = structuralPreviewText(for: kind) {
            return structuralPreviewText
        }

        if let embedPreviewText = embedPreviewText(for: kind) {
            return embedPreviewText
        }

        return fallbackPreviewText(for: kind)
    }

    private static func mediaPreviewText(for kind: NativeEditorBlockKind) -> String? {
        switch kind {
        case .table(let table):
            "\(table.rows.count) rows, \(table.columnCount) columns"
        case .image(let media), .video(let media):
            media.alternativeText ?? media.source ?? kind.accessibilityLabel
        case .audio(let media):
            media.source ?? "Audio"
        case .pdf(let pdf):
            pdf.name ?? pdf.source ?? "PDF"
        case .attachment(let attachment):
            attachment.name ?? attachment.url ?? "Attachment"
        default:
            nil
        }
    }

    private static func structuralPreviewText(for kind: NativeEditorBlockKind) -> String? {
        switch kind {
        case .callout(let callout):
            callout.previewText
        case .details(let details):
            details.summary
        case .pageBreak:
            "Page break"
        case .divider:
            "Divider"
        case .columns(let columns):
            columns.previewText
        case .subpages:
            "Subpages"
        case .transclusionSource(let source):
            source.previewText
        case .transclusionReference(let reference):
            reference.transclusionID ?? reference.sourcePageID ?? "Synced block reference"
        default:
            nil
        }
    }

    private static func embedPreviewText(for kind: NativeEditorBlockKind) -> String? {
        switch kind {
        case .embed(let embed):
            embed.source ?? embed.provider ?? "Embed"
        case .drawio(let diagram), .excalidraw(let diagram):
            diagram.title ?? diagram.alternativeText ?? diagram.source ?? kind.accessibilityLabel
        case .mathBlock(let math):
            math.text
        case .unsupported(let type):
            "Unsupported \(type) block"
        default:
            nil
        }
    }

    private static func fallbackPreviewText(for kind: NativeEditorBlockKind) -> String {
        switch kind {
        case .paragraph, .heading, .bulletListItem, .orderedListItem, .taskListItem, .blockquote, .codeBlock:
            ""
        default:
            kind.accessibilityLabel
        }
    }
}
