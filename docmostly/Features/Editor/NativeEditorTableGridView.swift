import SwiftUI

struct NativeEditorTableReadOnlyGrid: View {
    let table: NativeEditorTable
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        if table.rows.isEmpty || table.columnCount == 0 {
            NativeEditorEmptyTableView()
        } else {
            ScrollView(.horizontal) {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    ForEach(table.rows.indices, id: \.self) { rowIndex in
                        GridRow {
                            ForEach(0..<table.columnCount, id: \.self) { columnIndex in
                                NativeEditorTableReadOnlyCell(
                                    cell: cell(rowIndex: rowIndex, columnIndex: columnIndex),
                                    rowIndex: rowIndex,
                                    columnIndex: columnIndex,
                                    width: columnWidth(for: columnIndex)
                                )
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func cell(rowIndex: Int, columnIndex: Int) -> NativeEditorTableCell? {
        guard table.rows.indices.contains(rowIndex),
              table.rows[rowIndex].cells.indices.contains(columnIndex) else {
            return nil
        }

        return table.rows[rowIndex].cells[columnIndex]
    }

    private func columnWidth(for columnIndex: Int) -> CGFloat {
        NativeEditorTableLayout.columnWidth(
            for: table,
            columnIndex: columnIndex,
            isCompactWidth: isCompactWidth
        )
    }

    private var isCompactWidth: Bool {
        #if os(iOS)
        horizontalSizeClass == .compact
        #else
        false
        #endif
    }
}

struct NativeEditorTableEditableGrid: View {
    let blockID: UUID
    let table: NativeEditorTable
    let actions: NativeEditorTableEditingActions
    @Binding var selection: NativeEditorTableSelection?
    @Binding var actionSelection: NativeEditorTableSelection?
    @Binding var isShowingActionDialog: Bool
    @Binding var dragStartWidths: [Int: CGFloat]
    let focusedCell: FocusState<NativeEditorTableCellCoordinate?>.Binding
    let isCompactWidth: Bool

    var body: some View {
        if table.rows.isEmpty || table.columnCount == 0 {
            NativeEditorEditableEmptyTableView(blockID: blockID, actions: actions)
        } else {
            ScrollView(.horizontal) {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    NativeEditorTableColumnHandleRow(
                        table: table,
                        selection: $selection,
                        actionSelection: $actionSelection,
                        isShowingActionDialog: $isShowingActionDialog,
                        isCompactWidth: isCompactWidth
                    )

                    ForEach(table.rows.indices, id: \.self) { rowIndex in
                        GridRow {
                            NativeEditorTableRowHandle(
                                rowIndex: rowIndex,
                                selection: $selection,
                                actionSelection: $actionSelection,
                                isShowingActionDialog: $isShowingActionDialog
                            )

                            ForEach(0..<table.columnCount, id: \.self) { columnIndex in
                                if let cell = cell(rowIndex: rowIndex, columnIndex: columnIndex) {
                                    NativeEditorTableEditableCell(
                                        blockID: blockID,
                                        cell: cell,
                                        rowIndex: rowIndex,
                                        columnIndex: columnIndex,
                                        width: columnWidth(for: columnIndex),
                                        actions: actions,
                                        selection: $selection,
                                        dragStartWidths: $dragStartWidths,
                                        focusedCell: focusedCell
                                    )
                                } else {
                                    NativeEditorTableMissingCell(
                                        rowIndex: rowIndex,
                                        columnIndex: columnIndex,
                                        width: columnWidth(for: columnIndex)
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func cell(rowIndex: Int, columnIndex: Int) -> NativeEditorTableCell? {
        guard table.rows.indices.contains(rowIndex),
              table.rows[rowIndex].cells.indices.contains(columnIndex) else {
            return nil
        }

        return table.rows[rowIndex].cells[columnIndex]
    }

    private func columnWidth(for columnIndex: Int) -> CGFloat {
        NativeEditorTableLayout.columnWidth(
            for: table,
            columnIndex: columnIndex,
            isCompactWidth: isCompactWidth
        )
    }
}

private struct NativeEditorTableColumnHandleRow: View {
    let table: NativeEditorTable
    @Binding var selection: NativeEditorTableSelection?
    @Binding var actionSelection: NativeEditorTableSelection?
    @Binding var isShowingActionDialog: Bool
    let isCompactWidth: Bool

    var body: some View {
        GridRow {
            Color.clear
                .frame(
                    width: NativeEditorTableLayout.rowHandleWidth,
                    height: NativeEditorTableLayout.columnHandleHeight
                )

            ForEach(0..<table.columnCount, id: \.self) { columnIndex in
                NativeEditorTableColumnHandle(
                    columnIndex: columnIndex,
                    width: NativeEditorTableLayout.columnWidth(
                        for: table,
                        columnIndex: columnIndex,
                        isCompactWidth: isCompactWidth
                    ),
                    isSelected: selection == .column(columnIndex),
                    selection: $selection,
                    actionSelection: $actionSelection,
                    isShowingActionDialog: $isShowingActionDialog
                )
            }
        }
    }
}

private struct NativeEditorTableColumnHandle: View {
    let columnIndex: Int
    let width: CGFloat
    let isSelected: Bool
    @Binding var selection: NativeEditorTableSelection?
    @Binding var actionSelection: NativeEditorTableSelection?
    @Binding var isShowingActionDialog: Bool

    var body: some View {
        Button("Column \(columnIndex + 1) actions", systemImage: "ellipsis") {
            let nextSelection = NativeEditorTableSelection.column(columnIndex)
            selection = nextSelection
            actionSelection = nextSelection
            isShowingActionDialog = true
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? DocmostlyTheme.primary : .secondary)
        .frame(width: width, height: NativeEditorTableLayout.columnHandleHeight)
        .background(isSelected ? DocmostlyTheme.primaryTint : Color.clear, in: .rect(cornerRadius: 4))
        .help("Column \(columnIndex + 1) actions")
    }
}

private struct NativeEditorTableRowHandle: View {
    let rowIndex: Int
    @Binding var selection: NativeEditorTableSelection?
    @Binding var actionSelection: NativeEditorTableSelection?
    @Binding var isShowingActionDialog: Bool

    var body: some View {
        Button("Row \(rowIndex + 1) actions", systemImage: "ellipsis") {
            let nextSelection = NativeEditorTableSelection.row(rowIndex)
            selection = nextSelection
            actionSelection = nextSelection
            isShowingActionDialog = true
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .foregroundStyle(selection == .row(rowIndex) ? DocmostlyTheme.primary : .secondary)
        .frame(width: NativeEditorTableLayout.rowHandleWidth)
        .frame(minHeight: NativeEditorTableLayout.rowMinimumHeight)
        .background(selection == .row(rowIndex) ? DocmostlyTheme.primaryTint : Color.clear, in: .rect(cornerRadius: 4))
        .help("Row \(rowIndex + 1) actions")
    }
}

private struct NativeEditorTableEditableCell: View {
    let blockID: UUID
    let cell: NativeEditorTableCell
    let rowIndex: Int
    let columnIndex: Int
    let width: CGFloat
    let actions: NativeEditorTableEditingActions
    @Binding var selection: NativeEditorTableSelection?
    @Binding var dragStartWidths: [Int: CGFloat]
    let focusedCell: FocusState<NativeEditorTableCellCoordinate?>.Binding

    var body: some View {
        TextField("Cell", text: cellBinding, axis: .vertical)
            .textFieldStyle(.plain)
            .font(cell.isHeader ? .body.bold() : .body)
            .foregroundStyle(.primary)
            .lineLimit(4)
            .focused(focusedCell, equals: NativeEditorTableCellCoordinate(rowIndex: rowIndex, columnIndex: columnIndex))
            .padding(.horizontal, NativeEditorTableLayout.cellHorizontalPadding)
            .padding(.vertical, NativeEditorTableLayout.cellVerticalPadding)
            .frame(
                minWidth: width,
                maxWidth: width,
                minHeight: NativeEditorTableLayout.rowMinimumHeight,
                alignment: .topLeading
            )
            .background(NativeEditorTableLayout.cellBackground(for: cell))
            .overlay {
                NativeEditorTableSelectionStroke(isSelected: isSelected)
            }
            .overlay(alignment: .top) {
                NativeEditorTableCellBorder(edge: .top, isVisible: rowIndex == 0)
            }
            .overlay(alignment: .leading) {
                NativeEditorTableCellBorder(edge: .leading, isVisible: columnIndex == 0)
            }
            .overlay(alignment: .trailing) {
                ZStack(alignment: .trailing) {
                    NativeEditorTableCellBorder(edge: .trailing, isVisible: true)
                    NativeEditorTableColumnResizeHandle(
                        blockID: blockID,
                        columnIndex: columnIndex,
                        currentWidth: width,
                        actions: actions,
                        dragStartWidths: $dragStartWidths,
                        isActive: isSelected
                    )
                }
            }
            .overlay(alignment: .bottom) {
                NativeEditorTableCellBorder(edge: .bottom, isVisible: true)
            }
    }

    private var cellBinding: Binding<String> {
        Binding {
            cell.plainText
        } set: { text in
            actions.updateCell(blockID, rowIndex, columnIndex, text)
        }
    }

    private var isSelected: Bool {
        selection?.contains(rowIndex: rowIndex, columnIndex: columnIndex) == true
    }
}

private struct NativeEditorTableReadOnlyCell: View {
    let cell: NativeEditorTableCell?
    let rowIndex: Int
    let columnIndex: Int
    let width: CGFloat

    var body: some View {
        Text(displayText)
            .font(cell?.isHeader == true ? .body.bold() : .body)
            .foregroundStyle(.primary)
            .padding(.horizontal, NativeEditorTableLayout.cellHorizontalPadding)
            .padding(.vertical, NativeEditorTableLayout.cellVerticalPadding)
            .frame(
                minWidth: width,
                maxWidth: width,
                minHeight: NativeEditorTableLayout.rowMinimumHeight,
                alignment: .topLeading
            )
            .background(cell.map(NativeEditorTableLayout.cellBackground) ?? Color.clear)
            .overlay(alignment: .top) {
                NativeEditorTableCellBorder(edge: .top, isVisible: rowIndex == 0)
            }
            .overlay(alignment: .leading) {
                NativeEditorTableCellBorder(edge: .leading, isVisible: columnIndex == 0)
            }
            .overlay(alignment: .trailing) {
                NativeEditorTableCellBorder(edge: .trailing, isVisible: true)
            }
            .overlay(alignment: .bottom) {
                NativeEditorTableCellBorder(edge: .bottom, isVisible: true)
            }
    }

    private var displayText: String {
        guard let text = cell?.plainText, text.isEmpty == false else {
            return " "
        }

        return text
    }
}

private struct NativeEditorTableMissingCell: View {
    let rowIndex: Int
    let columnIndex: Int
    let width: CGFloat

    var body: some View {
        Color.secondary.opacity(0.04)
            .frame(
                minWidth: width,
                maxWidth: width,
                minHeight: NativeEditorTableLayout.rowMinimumHeight
            )
            .overlay(alignment: .top) {
                NativeEditorTableCellBorder(edge: .top, isVisible: rowIndex == 0)
            }
            .overlay(alignment: .leading) {
                NativeEditorTableCellBorder(edge: .leading, isVisible: columnIndex == 0)
            }
            .overlay(alignment: .trailing) {
                NativeEditorTableCellBorder(edge: .trailing, isVisible: true)
            }
            .overlay(alignment: .bottom) {
                NativeEditorTableCellBorder(edge: .bottom, isVisible: true)
            }
    }
}

private struct NativeEditorTableColumnResizeHandle: View {
    let blockID: UUID
    let columnIndex: Int
    let currentWidth: CGFloat
    let actions: NativeEditorTableEditingActions
    @Binding var dragStartWidths: [Int: CGFloat]
    let isActive: Bool

    var body: some View {
        Rectangle()
            .fill(isActive ? DocmostlyTheme.primary.opacity(0.45) : Color.clear)
            .frame(width: NativeEditorTableLayout.resizeHandleWidth)
            .contentShape(.rect)
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        if dragStartWidths[columnIndex] == nil {
                            dragStartWidths[columnIndex] = currentWidth
                        }

                        let startWidth = dragStartWidths[columnIndex] ?? currentWidth
                        let proposedWidth = startWidth + value.translation.width
                        actions.updateColumnWidth(blockID, columnIndex, Int(proposedWidth.rounded()))
                    }
                    .onEnded { _ in
                        dragStartWidths[columnIndex] = nil
                    }
            )
            .accessibilityLabel("Resize column \(columnIndex + 1)")
            .help("Resize column \(columnIndex + 1)")
    }
}

private enum NativeEditorTableCellBorderEdge {
    case top
    case leading
    case trailing
    case bottom
}

private struct NativeEditorTableCellBorder: View {
    let edge: NativeEditorTableCellBorderEdge
    let isVisible: Bool

    var body: some View {
        if isVisible {
            Rectangle()
                .fill(NativeEditorTableLayout.borderStyle)
                .frame(width: isVertical ? 1 : nil, height: isVertical ? nil : 1)
        }
    }

    private var isVertical: Bool {
        edge == .leading || edge == .trailing
    }
}

private struct NativeEditorTableSelectionStroke: View {
    let isSelected: Bool

    var body: some View {
        if isSelected {
            Rectangle()
                .stroke(DocmostlyTheme.primary.opacity(0.70), lineWidth: 2)
                .allowsHitTesting(false)
        }
    }
}
