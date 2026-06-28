import Foundation

nonisolated extension NativeEditorDocument {
    static func table(from node: ProseMirrorNode) -> NativeEditorTable {
        let rows = (node.content ?? [])
            .filter { $0.type == "tableRow" }
            .prefix(NativeEditorTable.maximumRowCount)
            .map { row in
            let cells = tableCells(from: row)
            return NativeEditorTableRow(cells: cells)
        }

        return NativeEditorTable(rows: rows)
    }

    static func mediaBlock(from node: ProseMirrorNode) -> NativeEditorMediaBlock {
        NativeEditorMediaBlock(
            source: node.attrs?["src"]?.stringValue,
            alternativeText: node.attrs?["alt"]?.stringValue,
            title: node.attrs?["title"]?.stringValue,
            attachmentID: node.attrs?["attachmentId"]?.stringValue,
            sizeInBytes: node.attrs?["size"]?.intValue,
            width: node.attrs?["width"]?.displayString,
            height: node.attrs?["height"]?.displayString,
            aspectRatio: node.attrs?["aspectRatio"]?.displayString,
            alignment: node.attrs?["align"]?.stringValue
        )
    }

    static func pdfBlock(from node: ProseMirrorNode) -> NativeEditorPDFBlock {
        NativeEditorPDFBlock(
            source: node.attrs?["src"]?.stringValue,
            name: node.attrs?["name"]?.stringValue,
            attachmentID: node.attrs?["attachmentId"]?.stringValue,
            sizeInBytes: node.attrs?["size"]?.intValue,
            width: node.attrs?["width"]?.displayString,
            height: node.attrs?["height"]?.displayString
        )
    }

    static func attachmentBlock(from node: ProseMirrorNode) -> NativeEditorAttachmentBlock {
        NativeEditorAttachmentBlock(
            url: node.attrs?["url"]?.stringValue,
            name: node.attrs?["name"]?.stringValue,
            mimeType: node.attrs?["mime"]?.stringValue,
            sizeInBytes: node.attrs?["size"]?.intValue,
            attachmentID: node.attrs?["attachmentId"]?.stringValue
        )
    }

    static func calloutBlock(from node: ProseMirrorNode) -> NativeEditorCalloutBlock {
        NativeEditorCalloutBlock(
            style: node.attrs?["type"]?.stringValue ?? "info",
            icon: node.attrs?["icon"]?.stringValue,
            previewText: plainText(in: node.content ?? [])
        )
    }

    static func detailsBlock(from node: ProseMirrorNode) -> NativeEditorDetailsBlock {
        let summaryNode = node.content?.first { $0.type == "detailsSummary" }
        let contentNode = node.content?.first { $0.type == "detailsContent" }

        return NativeEditorDetailsBlock(
            summary: plainText(in: summaryNode?.content ?? []),
            previewText: plainText(in: contentNode?.content ?? []),
            isOpen: node.attrs?["open"]?.boolValue ?? false
        )
    }

    static func columnsBlock(from node: ProseMirrorNode) -> NativeEditorColumnsBlock {
        let columns = (node.content ?? []).filter { $0.type == "column" }
        let columnTexts = columns.map { plainText(in: $0.content ?? []) }

        return NativeEditorColumnsBlock(
            layout: node.attrs?["layout"]?.stringValue ?? "two_equal",
            widthMode: node.attrs?["widthMode"]?.stringValue ?? "normal",
            columnCount: columns.count,
            previewText: columnTexts.joined(separator: " "),
            columnTexts: columnTexts
        )
    }

    static func transclusionSourceBlock(
        from node: ProseMirrorNode
    ) -> NativeEditorTransclusionSourceBlock {
        NativeEditorTransclusionSourceBlock(
            identifier: node.attrs?["id"]?.stringValue,
            previewText: plainText(in: node.content ?? [])
        )
    }

    static func transclusionReferenceBlock(
        from node: ProseMirrorNode
    ) -> NativeEditorTransclusionReferenceBlock {
        NativeEditorTransclusionReferenceBlock(
            sourcePageID: node.attrs?["sourcePageId"]?.stringValue,
            transclusionID: node.attrs?["transclusionId"]?.stringValue
        )
    }

    static func baseBlock(from node: ProseMirrorNode) -> NativeEditorBaseBlock {
        let pageID = node.attrs?["pageId"]?.stringValue
        return NativeEditorBaseBlock(
            pageID: pageID,
            pendingKey: node.attrs?["pendingKey"]?.stringValue,
            previewText: "Base"
        )
    }

    static func embedBlock(from node: ProseMirrorNode) -> NativeEditorEmbedBlock {
        NativeEditorEmbedBlock(
            source: node.attrs?["src"]?.stringValue,
            provider: node.attrs?["provider"]?.stringValue ?? youtubeProviderName(for: node),
            alignment: node.attrs?["align"]?.stringValue,
            width: node.attrs?["width"]?.displayString,
            height: node.attrs?["height"]?.displayString
        )
    }

    static func diagramBlock(from node: ProseMirrorNode) -> NativeEditorDiagramBlock {
        NativeEditorDiagramBlock(
            source: node.attrs?["src"]?.stringValue,
            title: node.attrs?["title"]?.stringValue,
            alternativeText: node.attrs?["alt"]?.stringValue,
            attachmentID: node.attrs?["attachmentId"]?.stringValue,
            sizeInBytes: node.attrs?["size"]?.intValue,
            width: node.attrs?["width"]?.displayString,
            height: node.attrs?["height"]?.displayString,
            aspectRatio: node.attrs?["aspectRatio"]?.displayString,
            alignment: node.attrs?["align"]?.stringValue
        )
    }

    static func mathBlock(from node: ProseMirrorNode) -> NativeEditorMathBlock {
        NativeEditorMathBlock(text: node.attrs?["text"]?.stringValue ?? plainText(in: node.content ?? []))
    }

    static func mention(from node: ProseMirrorNode) -> NativeEditorMention {
        NativeEditorMention(
            identifier: node.attrs?["id"]?.stringValue,
            label: node.attrs?["label"]?.stringValue,
            entityType: node.attrs?["entityType"]?.stringValue,
            entityID: node.attrs?["entityId"]?.stringValue,
            slugID: node.attrs?["slugId"]?.stringValue,
            creatorID: node.attrs?["creatorId"]?.stringValue,
            anchorID: node.attrs?["anchorId"]?.stringValue
        )
    }

    static func statusBadge(from node: ProseMirrorNode) -> NativeEditorStatusBadge {
        NativeEditorStatusBadge(
            text: node.attrs?["text"]?.stringValue ?? "",
            color: node.attrs?["color"]?.stringValue ?? "gray"
        )
    }

    private static func tableCells(from row: ProseMirrorNode) -> [NativeEditorTableCell] {
        let cellTypes = ["tableCell", "tableHeader"]

        return (row.content ?? [])
            .filter { cellTypes.contains($0.type) }
            .prefix(NativeEditorTable.maximumColumnCount)
            .map { cell in
                let columnWidths = tableColumnWidths(from: cell.attrs)
                return NativeEditorTableCell(
                    plainText: plainText(in: cell.content ?? []),
                    isHeader: cell.type == "tableHeader",
                    backgroundColorName: cell.attrs?["backgroundColorName"]?.stringValue,
                    columnWidth: columnWidths.first,
                    columnSpan: normalizedTableSpan(cell.attrs?["colspan"]?.intValue),
                    rowSpan: normalizedTableSpan(cell.attrs?["rowspan"]?.intValue),
                    columnWidths: columnWidths
                )
            }
    }

    private static func tableColumnWidths(from attrs: [String: ProseMirrorJSONValue]?) -> [Int] {
        guard let value = attrs?["colwidth"] ?? attrs?["colWidth"] else {
            return []
        }

        switch value {
        case .array(let values):
            return values.compactMap(\.intValue)
        default:
            return value.intValue.map { [$0] } ?? []
        }
    }

    private static func normalizedTableSpan(_ value: Int?) -> Int {
        max(value ?? 1, 1)
    }

    private static func youtubeProviderName(for node: ProseMirrorNode) -> String? {
        node.type == "youtube" ? "YouTube" : nil
    }
}
