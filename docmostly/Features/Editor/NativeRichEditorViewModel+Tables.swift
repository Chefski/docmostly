import Foundation

extension NativeRichEditorViewModel {
    func updateTableCell(blockID: UUID, rowIndex: Int, columnIndex: Int, text: String) {
        updateTable(blockID: blockID) { table in
            guard table.rows.indices.contains(rowIndex),
                  table.rows[rowIndex].cells.indices.contains(columnIndex) else {
                return
            }

            table.rows[rowIndex].cells[columnIndex].plainText = text
            table.rows[rowIndex].cells[columnIndex].inlineContent = nil
            table.rows[rowIndex].cells[columnIndex].preservedContent = nil
        }
    }

    func insertTableRowAbove(blockID: UUID, rowIndex: Int) {
        insertTableRow(blockID: blockID, insertionIndex: rowIndex)
    }

    func insertTableRowBelow(blockID: UUID, rowIndex: Int) {
        insertTableRow(blockID: blockID, insertionIndex: rowIndex + 1)
    }

    func deleteTableRow(blockID: UUID, rowIndex: Int) {
        updateTable(blockID: blockID) { table in
            guard table.rows.count > 1, table.rows.indices.contains(rowIndex) else { return }
            table.rows.remove(at: rowIndex)
        }
    }

    func insertTableColumnBefore(blockID: UUID, columnIndex: Int) {
        insertTableColumn(blockID: blockID, insertionIndex: columnIndex)
    }

    func insertTableColumnAfter(blockID: UUID, columnIndex: Int) {
        insertTableColumn(blockID: blockID, insertionIndex: columnIndex + 1)
    }

    func deleteTableColumn(blockID: UUID, columnIndex: Int) {
        updateTable(blockID: blockID) { table in
            guard table.columnCount > 1 else { return }

            for rowIndex in table.rows.indices where table.rows[rowIndex].cells.indices.contains(columnIndex) {
                table.rows[rowIndex].cells.remove(at: columnIndex)
            }
        }
    }

    func updateTableColumnWidth(blockID: UUID, columnIndex: Int, width: Int) {
        updateTable(blockID: blockID) { table in
            let clampedWidth = min(max(width, 96), 480)

            for rowIndex in table.rows.indices where table.rows[rowIndex].cells.indices.contains(columnIndex) {
                table.rows[rowIndex].cells[columnIndex].columnWidth = clampedWidth
                table.rows[rowIndex].cells[columnIndex].columnWidths = [clampedWidth]
            }
        }
    }

    private func insertTableRow(blockID: UUID, insertionIndex: Int) {
        updateTable(blockID: blockID) { table in
            let columnCount = max(table.columnCount, 1)
            let normalizedInsertionIndex = min(max(insertionIndex, 0), table.rows.count)
            let startsEmpty = table.rows.isEmpty
            let newRow = NativeEditorTableRow(cells: (0..<columnCount).map { columnIndex in
                NativeEditorTableCell(
                    plainText: "",
                    isHeader: startsEmpty,
                    backgroundColorName: nil,
                    columnWidth: table.columnWidth(at: columnIndex)
                )
            })
            table.rows.insert(newRow, at: normalizedInsertionIndex)
        }
    }

    private func insertTableColumn(blockID: UUID, insertionIndex: Int) {
        updateTable(blockID: blockID) { table in
            guard table.rows.isEmpty == false else {
                table.rows = [NativeEditorTableRow(cells: [
                    NativeEditorTableCell(plainText: "", isHeader: true, backgroundColorName: nil)
                ])]
                return
            }

            let normalizedInsertionIndex = min(max(insertionIndex, 0), max(table.columnCount, 0))
            let inheritedWidth = table.columnWidth(at: min(normalizedInsertionIndex, max(table.columnCount - 1, 0)))
            for rowIndex in table.rows.indices {
                let isHeader = table.rows[rowIndex].cells.first?.isHeader ?? (rowIndex == table.rows.startIndex)
                let newCell = NativeEditorTableCell(
                    plainText: "",
                    isHeader: isHeader,
                    backgroundColorName: nil,
                    columnWidth: inheritedWidth
                )
                let cellIndex = min(normalizedInsertionIndex, table.rows[rowIndex].cells.count)
                table.rows[rowIndex].cells.insert(newCell, at: cellIndex)
            }
        }
    }

    private func updateTable(blockID: UUID, edit: (inout NativeEditorTable) -> Void) {
        performUndoableEdit {
            guard
                let blockIndex = document.blocks.firstIndex(where: { $0.id == blockID }),
                case .table(var table) = document.blocks[blockIndex].kind
            else {
                return
            }

            edit(&table)
            document.blocks[blockIndex].kind = .table(table)
            document.blocks[blockIndex].rawNode = NativeEditorTableNodeFactory.node(from: table)
            document.blocks[blockIndex].text = AttributedString(NativeEditorDocument.previewText(for: .table(table)))
        }
    }
}

nonisolated enum NativeEditorTableNodeFactory {
    static func node(from table: NativeEditorTable) -> ProseMirrorNode {
        ProseMirrorNode(type: "table", content: table.rows.map(rowNode(from:)))
    }

    private static func rowNode(from row: NativeEditorTableRow) -> ProseMirrorNode {
        ProseMirrorNode(type: "tableRow", content: row.cells.map(cellNode(from:)))
    }

    private static func cellNode(from cell: NativeEditorTableCell) -> ProseMirrorNode {
        ProseMirrorNode(
            type: cell.isHeader ? "tableHeader" : "tableCell",
            attrs: cellAttrs(from: cell),
            content: cell.preservedContent ?? [paragraphNode(from: cell)]
        )
    }

    private static func cellAttrs(from cell: NativeEditorTableCell) -> [String: ProseMirrorJSONValue]? {
        var attrs: [String: ProseMirrorJSONValue] = [:]

        if let backgroundColor = cell.backgroundColor, backgroundColor.isEmpty == false {
            attrs["backgroundColor"] = .string(backgroundColor)
        }

        if let backgroundColorName = cell.backgroundColorName, backgroundColorName.isEmpty == false {
            attrs["backgroundColorName"] = .string(backgroundColorName.lowercased())
        }

        if let columnWidth = cell.columnWidth {
            attrs["colwidth"] = .array([.int(columnWidth)])
        }

        if cell.columnWidths.isEmpty == false {
            attrs["colwidth"] = .array(cell.columnWidths.map { .int($0) })
        }

        if cell.columnSpan > 1 {
            attrs["colspan"] = .int(cell.columnSpan)
        }

        if cell.rowSpan > 1 {
            attrs["rowspan"] = .int(cell.rowSpan)
        }

        return attrs.isEmpty ? nil : attrs
    }

    private static func paragraphNode(from cell: NativeEditorTableCell) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "paragraph",
            attrs: paragraphAttrs(from: cell),
            content: cell.inlineContent.map(NativeEditorDocument.inlineNodes(from:)) ??
                NativeEditorDocument.inlineNodes(from: AttributedString(cell.plainText))
        )
    }

    private static func paragraphAttrs(from cell: NativeEditorTableCell) -> [String: ProseMirrorJSONValue]? {
        guard let textAlignment = cell.textAlignment else { return nil }
        return ["textAlign": .string(textAlignment.rawValue)]
    }
}
