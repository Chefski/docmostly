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
    @State private var actionSelection: NativeEditorTableSelection?
    @State private var isShowingActionDialog = false
    @State private var dragStartWidths: [Int: CGFloat] = [:]
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
                actionSelection: $actionSelection,
                isShowingActionDialog: $isShowingActionDialog,
                dragStartWidths: $dragStartWidths,
                focusedCell: $focusedCell,
                isCompactWidth: isCompactWidth
            )

            NativeEditorTableActionBar(
                blockID: blockID,
                table: table,
                actions: actions,
                selection: selection,
                actionSelection: $actionSelection,
                isShowingActionDialog: $isShowingActionDialog
            )
        }
        .confirmationDialog(
            actionSelection?.actionTitle ?? "Table actions",
            isPresented: $isShowingActionDialog,
            titleVisibility: .visible
        ) {
            if let actionSelection {
                NativeEditorTableDialogActions(
                    blockID: blockID,
                    table: table,
                    selection: actionSelection,
                    actions: actions
                )
            }

            Button("Cancel", role: .cancel) {}
        }
        .onChange(of: focusedCell) { _, coordinate in
            guard let coordinate else { return }
            selection = .cell(rowIndex: coordinate.rowIndex, columnIndex: coordinate.columnIndex)
        }
        .onChange(of: table) { _, updatedTable in
            guard let selection, updatedTable.contains(selection) == false else { return }
            self.selection = nil
            actionSelection = nil
        }
    }

    private var isCompactWidth: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }
}
