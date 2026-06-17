import Foundation
import SwiftUI

extension NativeEditorCommand {
    func replacementBlock(reusing id: UUID) -> NativeEditorBlock? {
        if let structuralBlock = structuralReplacementBlock(reusing: id) {
            return structuralBlock
        }

        if let embeddedBlock = embeddedReplacementBlock(reusing: id) {
            return embeddedBlock
        }

        return textReplacementBlock(reusing: id)
    }

    private func structuralReplacementBlock(reusing id: UUID) -> NativeEditorBlock? {
        switch self {
        case .table:
            richBlock(id: id, kind: blockKind, rawNode: tableNode)
        case .callout:
            richBlock(id: id, kind: blockKind, rawNode: calloutNode)
        case .details:
            richBlock(id: id, kind: blockKind, rawNode: detailsNode)
        case .pageBreak:
            richBlock(id: id, kind: blockKind, rawNode: ProseMirrorNode(type: "pageBreak"))
        case .divider:
            richBlock(id: id, kind: blockKind, rawNode: ProseMirrorNode(type: "horizontalRule"))
        case .columns:
            richBlock(id: id, kind: blockKind, rawNode: columnsNode)
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
        case .embed:
            richBlock(id: id, kind: blockKind, rawNode: embedNode)
        case .mathBlock:
            richBlock(id: id, kind: blockKind, rawNode: mathBlockNode)
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

    private var columnsNode: ProseMirrorNode {
        ProseMirrorNode(
            type: "columns",
            attrs: ["layout": .string("two_equal")],
            content: [
                columnNode(text: "Left"),
                columnNode(text: "Right")
            ]
        )
    }

    private func columnNode(text: String) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "column",
            attrs: ["width": .int(1)],
            content: [paragraphNode(text)]
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

    private var embedNode: ProseMirrorNode {
        ProseMirrorNode(
            type: "embed",
            attrs: ["src": .string("https://example.com"), "provider": .string("Embed")]
        )
    }

    private var mathBlockNode: ProseMirrorNode {
        ProseMirrorNode(type: "mathBlock", attrs: ["text": .string("E = mc^2")])
    }

    private func paragraphNode(_ text: String) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "paragraph",
            content: NativeEditorDocument.inlineNodes(from: AttributedString(text))
        )
    }
}
