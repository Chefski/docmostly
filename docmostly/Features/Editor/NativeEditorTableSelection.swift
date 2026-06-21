import Foundation

struct NativeEditorTableCellCoordinate: Hashable, Sendable {
    let rowIndex: Int
    let columnIndex: Int
}

struct NativeEditorTableSelection: Identifiable, Equatable, Sendable {
    enum Kind: Sendable {
        case cell
        case row
        case column
    }

    let kind: Kind
    let rowIndex: Int?
    let columnIndex: Int?

    var id: String {
        switch kind {
        case .cell:
            "cell-\(rowIndex ?? 0)-\(columnIndex ?? 0)"
        case .row:
            "row-\(rowIndex ?? 0)"
        case .column:
            "column-\(columnIndex ?? 0)"
        }
    }

    var summaryTitle: String {
        switch kind {
        case .cell:
            "Cell \(displayRow), \(displayColumn)"
        case .row:
            "Row \(displayRow)"
        case .column:
            "Column \(displayColumn)"
        }
    }

    var actionTitle: String {
        "\(summaryTitle) actions"
    }

    static func cell(rowIndex: Int, columnIndex: Int) -> NativeEditorTableSelection {
        NativeEditorTableSelection(kind: .cell, rowIndex: rowIndex, columnIndex: columnIndex)
    }

    static func row(_ rowIndex: Int) -> NativeEditorTableSelection {
        NativeEditorTableSelection(kind: .row, rowIndex: rowIndex, columnIndex: nil)
    }

    static func column(_ columnIndex: Int) -> NativeEditorTableSelection {
        NativeEditorTableSelection(kind: .column, rowIndex: nil, columnIndex: columnIndex)
    }

    func contains(rowIndex: Int, columnIndex: Int) -> Bool {
        switch kind {
        case .cell:
            self.rowIndex == rowIndex && self.columnIndex == columnIndex
        case .row:
            self.rowIndex == rowIndex
        case .column:
            self.columnIndex == columnIndex
        }
    }

    private var displayRow: Int {
        (rowIndex ?? 0) + 1
    }

    private var displayColumn: Int {
        (columnIndex ?? 0) + 1
    }
}

extension NativeEditorTable {
    func contains(_ selection: NativeEditorTableSelection) -> Bool {
        switch selection.kind {
        case .cell:
            guard let rowIndex = selection.rowIndex, let columnIndex = selection.columnIndex else {
                return false
            }

            return rows.indices.contains(rowIndex) && rows[rowIndex].cells.indices.contains(columnIndex)
        case .row:
            guard let rowIndex = selection.rowIndex else {
                return false
            }

            return rows.indices.contains(rowIndex)
        case .column:
            guard let columnIndex = selection.columnIndex else {
                return false
            }

            return columnIndex >= 0 && columnIndex < columnCount
        }
    }
}
