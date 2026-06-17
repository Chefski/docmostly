import Foundation

extension NativeRichEditorViewModel {
    func updateTableCell(blockID: UUID, rowIndex: Int, columnIndex: Int, text: String) {
        updateTable(blockID: blockID) { table in
            guard table.rows.indices.contains(rowIndex),
                  table.rows[rowIndex].cells.indices.contains(columnIndex) else {
                return
            }

            table.rows[rowIndex].cells[columnIndex].plainText = text
        }
    }

    func insertTableRowBelow(blockID: UUID, rowIndex: Int) {
        updateTable(blockID: blockID) { table in
            let columnCount = max(table.columnCount, 1)
            let insertionIndex = min(max(rowIndex + 1, 0), table.rows.count)
            let newRow = NativeEditorTableRow(cells: (0..<columnCount).map { _ in
                NativeEditorTableCell(plainText: "", isHeader: false, backgroundColorName: nil)
            })
            table.rows.insert(newRow, at: insertionIndex)
        }
    }

    func deleteTableRow(blockID: UUID, rowIndex: Int) {
        updateTable(blockID: blockID) { table in
            guard table.rows.count > 1, table.rows.indices.contains(rowIndex) else { return }
            table.rows.remove(at: rowIndex)
        }
    }

    func insertTableColumnAfter(blockID: UUID, columnIndex: Int) {
        updateTable(blockID: blockID) { table in
            guard table.rows.isEmpty == false else {
                table.rows = [NativeEditorTableRow(cells: [
                    NativeEditorTableCell(plainText: "", isHeader: true, backgroundColorName: nil)
                ])]
                return
            }

            let insertionIndex = min(max(columnIndex + 1, 0), max(table.columnCount, 0))
            for rowIndex in table.rows.indices {
                let isHeader = table.rows[rowIndex].cells.first?.isHeader ?? (rowIndex == table.rows.startIndex)
                let newCell = NativeEditorTableCell(plainText: "", isHeader: isHeader, backgroundColorName: nil)
                let cellIndex = min(insertionIndex, table.rows[rowIndex].cells.count)
                table.rows[rowIndex].cells.insert(newCell, at: cellIndex)
            }
        }
    }

    func deleteTableColumn(blockID: UUID, columnIndex: Int) {
        updateTable(blockID: blockID) { table in
            guard table.columnCount > 1 else { return }

            for rowIndex in table.rows.indices where table.rows[rowIndex].cells.indices.contains(columnIndex) {
                table.rows[rowIndex].cells.remove(at: columnIndex)
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

private enum NativeEditorTableNodeFactory {
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
            content: [paragraphNode(cell.plainText)]
        )
    }

    private static func cellAttrs(from cell: NativeEditorTableCell) -> [String: ProseMirrorJSONValue]? {
        guard let backgroundColorName = cell.backgroundColorName, backgroundColorName.isEmpty == false else {
            return nil
        }

        return ["backgroundColorName": .string(backgroundColorName.lowercased())]
    }

    private static func paragraphNode(_ text: String) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "paragraph",
            content: NativeEditorDocument.inlineNodes(from: AttributedString(text))
        )
    }
}
