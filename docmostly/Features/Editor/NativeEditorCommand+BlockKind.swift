import Foundation

extension NativeEditorCommand {
    var blockKind: NativeEditorBlockKind {
        switch self {
        case .paragraph:
            .paragraph
        case .heading1:
            .heading(level: 1)
        case .heading2:
            .heading(level: 2)
        case .heading3:
            .heading(level: 3)
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
        case .image:
            .image(NativeEditorMediaBlock.placeholder)
        case .video:
            .video(NativeEditorMediaBlock.placeholder)
        case .audio:
            .audio(NativeEditorMediaBlock.placeholder)
        case .pdf:
            .pdf(NativeEditorPDFBlock.placeholder)
        case .fileAttachment:
            .attachment(NativeEditorAttachmentBlock.placeholder)
        case .table:
            .table(NativeEditorTable(rows: defaultTableRows))
        case .baseInline:
            .base(NativeEditorBaseBlock(pageID: nil, pendingKey: nil, previewText: "Base"))
        case .kanban:
            .base(NativeEditorBaseBlock(pageID: nil, pendingKey: nil, previewText: "Kanban"))
        case .callout:
            .callout(NativeEditorCalloutBlock(style: "info", icon: nil, previewText: "Callout"))
        case .details:
            .details(NativeEditorDetailsBlock(summary: "Details", previewText: "Details", isOpen: true))
        case .mathInline:
            .paragraph
        case .pageBreak:
            .pageBreak
        case .divider:
            .divider
        case .columns:
            columnsBlock(layout: "two_equal", columnCount: 2)
        case .columns3:
            columnsBlock(layout: "three_equal", columnCount: 3)
        case .columns4:
            columnsBlock(layout: "four_equal", columnCount: 4)
        case .columns5:
            columnsBlock(layout: "five_equal", columnCount: 5)
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
                alignment: NativeEditorEmbedBlock.defaultAlignment,
                width: NativeEditorEmbedBlock.defaultWidth,
                height: NativeEditorEmbedBlock.defaultHeight
            ))
        case .iframeEmbed:
            embedBlock(provider: "iframe")
        case .airtableEmbed:
            embedBlock(provider: "airtable")
        case .loomEmbed:
            embedBlock(provider: "loom")
        case .figmaEmbed:
            embedBlock(provider: "figma")
        case .typeformEmbed:
            embedBlock(provider: "typeform")
        case .miroEmbed:
            embedBlock(provider: "miro")
        case .youtubeEmbed:
            embedBlock(provider: "youtube")
        case .vimeoEmbed:
            embedBlock(provider: "vimeo")
        case .framerEmbed:
            embedBlock(provider: "framer")
        case .googleDriveEmbed:
            embedBlock(provider: "gdrive")
        case .googleSheetsEmbed:
            embedBlock(provider: "gsheets")
        case .mathBlock:
            .mathBlock(NativeEditorMathBlock(text: "E = mc^2"))
        case .mermaid:
            .codeBlock(language: "mermaid")
        case .drawio:
            .drawio(NativeEditorDiagramBlock.placeholder)
        case .excalidraw:
            .excalidraw(NativeEditorDiagramBlock.placeholder)
        case .date, .time, .status, .emoji:
            .paragraph
        }
    }

    private func columnsBlock(layout: String, columnCount: Int) -> NativeEditorBlockKind {
        let labels = (1...columnCount).map { "Column \($0)" }
        return .columns(NativeEditorColumnsBlock(
            layout: layout,
            widthMode: "wide",
            columnCount: columnCount,
            previewText: labels.joined(separator: " "),
            columnTexts: labels
        ))
    }

    private func embedBlock(provider: String) -> NativeEditorBlockKind {
        .embed(NativeEditorEmbedBlock(
            source: nil,
            provider: provider,
            alignment: NativeEditorEmbedBlock.defaultAlignment,
            width: NativeEditorEmbedBlock.defaultWidth,
            height: NativeEditorEmbedBlock.defaultHeight
        ))
    }
}
