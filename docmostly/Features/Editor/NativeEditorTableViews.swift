import SwiftUI

struct NativeEditorTablePreview: View {
    let table: NativeEditorTable

    var body: some View {
        NativeEditorTableReadOnlyGrid(table: table)
            .accessibilityLabel("Table, \(table.rows.count) rows, \(table.columnCount) columns")
    }
}

struct NativeEditorTableEditor: View {
    let blockID: UUID
    let table: NativeEditorTable
    let actions: NativeEditorTableEditingActions

    @State private var selection: NativeEditorTableSelection?
    @State private var dragStartWidths: [Int: CGFloat] = [:]
    @State private var pendingFocus: NativeEditorTableCellCoordinate?
    @FocusState private var focusedCell: NativeEditorTableCellCoordinate?
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NativeEditorTableEditableGrid(
                blockID: blockID,
                table: table,
                actions: actions,
                selection: $selection,
                dragStartWidths: $dragStartWidths,
                focusedCell: $focusedCell,
                isCompactWidth: isCompactWidth,
                moveFocus: moveFocus
            )
        }
        .onChange(of: focusedCell) { _, coordinate in
            guard let coordinate else { return }
            selection = .cell(rowIndex: coordinate.rowIndex, columnIndex: coordinate.columnIndex)
        }
        .onChange(of: table) { _, updatedTable in
            if let pendingFocus,
               updatedTable.rows.indices.contains(pendingFocus.rowIndex),
               updatedTable.rows[pendingFocus.rowIndex].cells.indices.contains(pendingFocus.columnIndex) {
                focusedCell = pendingFocus
                selection = .cell(rowIndex: pendingFocus.rowIndex, columnIndex: pendingFocus.columnIndex)
                self.pendingFocus = nil
            }
            guard let selection, updatedTable.contains(selection) == false else { return }
            self.selection = nil
        }
    }

    private var isCompactWidth: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }

    private func moveFocus(
        _ coordinate: NativeEditorTableCellCoordinate,
        _ direction: NativeEditorTableFocusDirection
    ) {
        guard let destination = NativeEditorTableFocusNavigation.destination(
            from: coordinate,
            direction: direction,
            rowCount: table.rows.count,
            columnCount: table.columnCount
        ) else {
            return
        }

        switch destination {
        case .cell(let coordinate):
            focusedCell = coordinate
        case .appendRowAndFocus(let coordinate):
            pendingFocus = coordinate
            actions.insertRowBelow(blockID, max(table.rows.count - 1, 0))
        }
    }
}
