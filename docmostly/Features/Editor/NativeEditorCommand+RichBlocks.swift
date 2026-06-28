import Foundation
import SwiftUI

extension NativeEditorCommand {
    func replacementBlock(reusing id: UUID) -> NativeEditorBlock? {
        if let mediaBlock = mediaReplacementBlock(reusing: id) {
            return mediaBlock
        }

        if let structuralBlock = structuralReplacementBlock(reusing: id) {
            return structuralBlock
        }

        if let embeddedBlock = embeddedReplacementBlock(reusing: id) {
            return embeddedBlock
        }

        return textReplacementBlock(reusing: id)
    }

    private func mediaReplacementBlock(reusing id: UUID) -> NativeEditorBlock? {
        switch self {
        case .image:
            mediaBlock(reusing: id, type: "image", kind: blockKind)
        case .video:
            mediaBlock(reusing: id, type: "video", kind: blockKind)
        case .audio:
            mediaBlock(reusing: id, type: "audio", kind: blockKind)
        case .pdf:
            richBlock(
                id: id,
                kind: blockKind,
                rawNode: NativeEditorRichBlockNodeFactory.pdfNode(from: .placeholder)
            )
        case .fileAttachment:
            richBlock(
                id: id,
                kind: blockKind,
                rawNode: NativeEditorRichBlockNodeFactory.attachmentNode(from: .placeholder)
            )
        default:
            nil
        }
    }

    private func structuralReplacementBlock(reusing id: UUID) -> NativeEditorBlock? {
        switch self {
        case .table:
            richBlock(id: id, kind: blockKind, rawNode: tableNode)
        case .baseInline, .kanban:
            richBlock(
                id: id,
                kind: blockKind,
                rawNode: NativeEditorRichBlockNodeFactory.baseNode(from: baseBlock)
            )
        case .callout:
            richBlock(id: id, kind: blockKind, rawNode: calloutNode)
        case .details:
            richBlock(id: id, kind: blockKind, rawNode: detailsNode)
        case .pageBreak:
            richBlock(id: id, kind: blockKind, rawNode: ProseMirrorNode(type: "pageBreak"))
        case .divider:
            richBlock(id: id, kind: blockKind, rawNode: ProseMirrorNode(type: "horizontalRule"))
        case .columns, .columns3, .columns4, .columns5:
            richBlock(
                id: id,
                kind: blockKind,
                rawNode: NativeEditorRichBlockNodeFactory.columnsNode(from: columnsBlock)
            )
        case .subpages:
            richBlock(id: id, kind: blockKind, rawNode: ProseMirrorNode(type: "subpages"))
        case .syncedBlock:
            syncedBlock(reusing: id)
        default:
            nil
        }
    }

    private func embeddedReplacementBlock(reusing id: UUID) -> NativeEditorBlock? {
        switch self {
        case .embed, .iframeEmbed, .airtableEmbed, .loomEmbed, .figmaEmbed, .typeformEmbed, .miroEmbed,
                .youtubeEmbed, .vimeoEmbed, .framerEmbed, .googleDriveEmbed, .googleSheetsEmbed:
            richBlock(
                id: id,
                kind: blockKind,
                rawNode: NativeEditorRichBlockNodeFactory.embedNode(from: embedBlock)
            )
        case .mathBlock:
            richBlock(id: id, kind: blockKind, rawNode: mathBlockNode)
        case .drawio:
            richBlock(id: id, kind: blockKind, rawNode: diagramNode(type: "drawio"))
        case .excalidraw:
            richBlock(id: id, kind: blockKind, rawNode: diagramNode(type: "excalidraw"))
        default:
            nil
        }
    }

    private func textReplacementBlock(reusing id: UUID) -> NativeEditorBlock? {
        guard case .mermaid = self else { return nil }

        return NativeEditorBlock(
            id: id,
            kind: .codeBlock(language: "mermaid"),
            text: AttributedString("graph TD; A-->B"),
            alignment: .left
        )
    }

    var defaultTableRows: [NativeEditorTableRow] {
        [
            NativeEditorTableRow(cells: [
                NativeEditorTableCell(plainText: "Column 1", isHeader: true, backgroundColorName: nil),
                NativeEditorTableCell(plainText: "Column 2", isHeader: true, backgroundColorName: nil)
            ]),
            NativeEditorTableRow(cells: [
                NativeEditorTableCell(plainText: "", isHeader: false, backgroundColorName: nil),
                NativeEditorTableCell(plainText: "", isHeader: false, backgroundColorName: nil)
            ])
        ]
    }

    private var baseBlock: NativeEditorBaseBlock {
        if case .base(let base) = blockKind {
            return base
        }

        return NativeEditorBaseBlock(pageID: nil, pendingKey: nil, previewText: "Base")
    }

    private var defaultSyncedBlockID: String {
        "sync-\(UUID().uuidString)"
    }

    private func richBlock(id: UUID, kind: NativeEditorBlockKind, rawNode: ProseMirrorNode) -> NativeEditorBlock {
        NativeEditorBlock(
            id: id,
            kind: kind,
            text: AttributedString(NativeEditorDocument.previewText(for: kind)),
            alignment: .left,
            rawNode: rawNode
        )
    }

    private func mediaBlock(id: UUID, type: String, kind: NativeEditorBlockKind) -> NativeEditorBlock {
        richBlock(
            id: id,
            kind: kind,
            rawNode: NativeEditorRichBlockNodeFactory.mediaNode(from: .placeholder, type: type)
        )
    }

    private func mediaBlock(reusing id: UUID, type: String, kind: NativeEditorBlockKind) -> NativeEditorBlock {
        mediaBlock(id: id, type: type, kind: kind)
    }

    private var tableNode: ProseMirrorNode {
        ProseMirrorNode(type: "table", content: [
            tableRowNode(cellType: "tableHeader", texts: ["Column 1", "Column 2"]),
            tableRowNode(cellType: "tableCell", texts: ["", ""])
        ])
    }

    private func tableRowNode(cellType: String, texts: [String]) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "tableRow",
            content: texts.map { text in
                ProseMirrorNode(
                    type: cellType,
                    content: [paragraphNode(text)]
                )
            }
        )
    }

    private var calloutNode: ProseMirrorNode {
        ProseMirrorNode(
            type: "callout",
            attrs: ["type": .string("info"), "icon": .string("lightbulb")],
            content: [paragraphNode("Callout")]
        )
    }

    private var detailsNode: ProseMirrorNode {
        ProseMirrorNode(
            type: "details",
            attrs: ["open": .bool(true)],
            content: [
                ProseMirrorNode(
                    type: "detailsSummary",
                    content: NativeEditorDocument.inlineNodes(from: AttributedString("Details"))
                ),
                ProseMirrorNode(type: "detailsContent", content: [paragraphNode("Details")])
            ]
        )
    }

    private var columnsBlock: NativeEditorColumnsBlock {
        if case .columns(let columns) = blockKind {
            return columns
        }

        return NativeEditorColumnsBlock(
            layout: "two_equal",
            widthMode: "wide",
            columnCount: 2,
            previewText: "Column 1 Column 2",
            columnTexts: ["Column 1", "Column 2"]
        )
    }

    private func syncedBlock(reusing id: UUID) -> NativeEditorBlock {
        let identifier = defaultSyncedBlockID
        return richBlock(
            id: id,
            kind: .transclusionSource(NativeEditorTransclusionSourceBlock(
                identifier: identifier,
                previewText: "Synced block"
            )),
            rawNode: syncedBlockNode(identifier: identifier)
        )
    }

    private func syncedBlockNode(identifier: String) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "transclusionSource",
            attrs: ["id": .string(identifier)],
            content: [paragraphNode("Synced block")]
        )
    }

    private var embedBlock: NativeEditorEmbedBlock {
        if case .embed(let embed) = blockKind {
            return embed
        }

        return NativeEditorEmbedBlock(
            source: nil,
            provider: "Embed",
            alignment: nil,
            width: nil,
            height: nil
        )
    }

    private var mathBlockNode: ProseMirrorNode {
        ProseMirrorNode(type: "mathBlock", attrs: ["text": .string("E = mc^2")])
    }

    private func diagramNode(type: String) -> ProseMirrorNode {
        NativeEditorRichBlockNodeFactory.diagramNode(from: .placeholder, type: type)
    }

    private func paragraphNode(_ text: String) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "paragraph",
            content: NativeEditorDocument.inlineNodes(from: AttributedString(text))
        )
    }
}
