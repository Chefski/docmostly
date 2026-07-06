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
                .padding(.vertical, NativeEditorTableLayout.gridVerticalPadding)
            }
            .scrollIndicators(.hidden)
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
                        blockID: blockID,
                        table: table,
                        actions: actions,
                        selection: $selection,
                        isCompactWidth: isCompactWidth
                    )

                    ForEach(table.rows.indices, id: \.self) { rowIndex in
                        GridRow {
                            NativeEditorTableRowHandle(
                                blockID: blockID,
                                table: table,
                                actions: actions,
                                rowIndex: rowIndex,
                                selection: $selection
                            )

                            ForEach(0..<table.columnCount, id: \.self) { columnIndex in
                                if let cell = cell(rowIndex: rowIndex, columnIndex: columnIndex) {
                                    NativeEditorTableEditableCell(
                                        blockID: blockID,
                                        cell: cell,
                                        rowIndex: rowIndex,
                                        columnIndex: columnIndex,
                                        rowCount: table.rows.count,
                                        columnCount: table.columnCount,
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
                .padding(.vertical, NativeEditorTableLayout.gridVerticalPadding)
            }
            .scrollIndicators(.hidden)
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
    let blockID: UUID
    let table: NativeEditorTable
    let actions: NativeEditorTableEditingActions
    @Binding var selection: NativeEditorTableSelection?
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
                    blockID: blockID,
                    table: table,
                    actions: actions,
                    columnIndex: columnIndex,
                    width: NativeEditorTableLayout.columnWidth(
                        for: table,
                        columnIndex: columnIndex,
                        isCompactWidth: isCompactWidth
                    ),
                    isSelected: selection == .column(columnIndex),
                    selection: $selection
                )
            }
        }
    }
}

private struct NativeEditorTableColumnHandle: View {
    let blockID: UUID
    let table: NativeEditorTable
    let actions: NativeEditorTableEditingActions
    let columnIndex: Int
    let width: CGFloat
    let isSelected: Bool
    @Binding var selection: NativeEditorTableSelection?

    var body: some View {
        Menu {
            Button("Delete Column", systemImage: "rectangle.badge.minus") {
                selection = .column(columnIndex)
                actions.deleteColumn(blockID, columnIndex)
            }
            .disabled(table.columnCount <= 1)

            Button("Add Column", systemImage: "rectangle.badge.plus") {
                selection = .column(columnIndex)
                actions.insertColumnAfter(blockID, columnIndex)
            }
        } label: {
            Image(systemName: "ellipsis")
                .accessibilityLabel("Column \(columnIndex + 1) actions")
        }
        .buttonStyle(.plain)
        .font(.caption.bold())
        .foregroundStyle(
            isSelected ? NativeEditorTableLayout.selectionAccent : NativeEditorTableLayout.handleForeground
        )
        .frame(width: width, height: NativeEditorTableLayout.columnHandleHeight)
        .help("Column \(columnIndex + 1) actions")
    }
}

private struct NativeEditorTableRowHandle: View {
    let blockID: UUID
    let table: NativeEditorTable
    let actions: NativeEditorTableEditingActions
    let rowIndex: Int
    @Binding var selection: NativeEditorTableSelection?

    var body: some View {
        Menu {
            Button("Delete Row", systemImage: "rectangle.badge.minus") {
                selection = .row(rowIndex)
                actions.deleteRow(blockID, rowIndex)
            }
            .disabled(table.rows.count <= 1)

            Button("Add Row", systemImage: "rectangle.badge.plus") {
                selection = .row(rowIndex)
                actions.insertRowBelow(blockID, rowIndex)
            }
        } label: {
            Image(systemName: "ellipsis")
                .rotationEffect(.degrees(90))
                .accessibilityLabel("Row \(rowIndex + 1) actions")
        }
        .buttonStyle(.plain)
        .font(.caption.bold())
        .foregroundStyle(
            isSelected ? NativeEditorTableLayout.selectionAccent : NativeEditorTableLayout.handleForeground
        )
        .frame(width: NativeEditorTableLayout.rowHandleWidth)
        .frame(minHeight: NativeEditorTableLayout.rowMinimumHeight)
        .help("Row \(rowIndex + 1) actions")
    }

    private var isSelected: Bool {
        selection == .row(rowIndex)
    }
}

private struct NativeEditorTableEditableCell: View {
    let blockID: UUID
    let cell: NativeEditorTableCell
    let rowIndex: Int
    let columnIndex: Int
    let rowCount: Int
    let columnCount: Int
    let width: CGFloat
    let actions: NativeEditorTableEditingActions
    @Binding var selection: NativeEditorTableSelection?
    @Binding var dragStartWidths: [Int: CGFloat]
    let focusedCell: FocusState<NativeEditorTableCellCoordinate?>.Binding

    var body: some View {
        TextField("Cell", text: cellBinding, axis: .vertical)
            .textFieldStyle(.plain)
            .font(NativeEditorTableLayout.font(for: cell))
            .foregroundStyle(cell.isHeader ? .primary : NativeEditorTableLayout.bodyForeground)
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
                NativeEditorTableSelectionFill(
                    selection: selection,
                    rowIndex: rowIndex,
                    columnIndex: columnIndex
                )
            }
            .overlay {
                NativeEditorTableSelectionStroke(
                    selection: selection,
                    rowIndex: rowIndex,
                    columnIndex: columnIndex,
                    rowCount: rowCount,
                    columnCount: columnCount
                )
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
            .font(cell.map(NativeEditorTableLayout.font) ?? .callout)
            .foregroundStyle(cell?.isHeader == true ? .primary : NativeEditorTableLayout.bodyForeground)
            .fixedSize(horizontal: false, vertical: true)
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
            .fill(isActive ? NativeEditorTableLayout.selectionAccent.opacity(0.80) : Color.clear)
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
    let selection: NativeEditorTableSelection?
    let rowIndex: Int
    let columnIndex: Int
    let rowCount: Int
    let columnCount: Int

    var body: some View {
        if selection?.contains(rowIndex: rowIndex, columnIndex: columnIndex) == true {
            ZStack {
                if showsFullCellStroke {
                    Rectangle()
                        .stroke(NativeEditorTableLayout.selectionAccent, lineWidth: 2)
                }

                if showsTopEdge {
                    NativeEditorTableSelectionEdge(edge: .top)
                }

                if showsLeadingEdge {
                    NativeEditorTableSelectionEdge(edge: .leading)
                }

                if showsTrailingEdge {
                    NativeEditorTableSelectionEdge(edge: .trailing)
                }

                if showsBottomEdge {
                    NativeEditorTableSelectionEdge(edge: .bottom)
                }
            }
            .foregroundStyle(NativeEditorTableLayout.selectionAccent)
            .allowsHitTesting(false)
        }
    }

    private var showsFullCellStroke: Bool {
        selection?.kind == .cell
    }

    private var showsTopEdge: Bool {
        switch selection?.kind {
        case .row:
            true
        case .column:
            rowIndex == 0
        case .cell, nil:
            false
        }
    }

    private var showsLeadingEdge: Bool {
        switch selection?.kind {
        case .row:
            columnIndex == 0
        case .column:
            true
        case .cell, nil:
            false
        }
    }

    private var showsTrailingEdge: Bool {
        switch selection?.kind {
        case .row:
            columnIndex == columnCount - 1
        case .column:
            true
        case .cell, nil:
            false
        }
    }

    private var showsBottomEdge: Bool {
        switch selection?.kind {
        case .row:
            true
        case .column:
            rowIndex == rowCount - 1
        case .cell, nil:
            false
        }
    }
}

private struct NativeEditorTableSelectionEdge: View {
    let edge: NativeEditorTableCellBorderEdge

    var body: some View {
        Rectangle()
            .fill(NativeEditorTableLayout.selectionAccent)
            .frame(width: isVertical ? 2 : nil, height: isVertical ? nil : 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }

    private var isVertical: Bool {
        edge == .leading || edge == .trailing
    }

    private var alignment: Alignment {
        switch edge {
        case .top:
            .top
        case .leading:
            .leading
        case .trailing:
            .trailing
        case .bottom:
            .bottom
        }
    }
}

private struct NativeEditorTableSelectionFill: View {
    let selection: NativeEditorTableSelection?
    let rowIndex: Int
    let columnIndex: Int

    var body: some View {
        if selection?.contains(rowIndex: rowIndex, columnIndex: columnIndex) == true {
            switch selection?.kind {
            case .row where columnIndex == 0:
                indicator(width: 4, height: nil, alignment: .leading)
            case .column where rowIndex == 0:
                indicator(width: nil, height: 4, alignment: .top)
            default:
                EmptyView()
            }
        }
    }

    private func indicator(width: CGFloat?, height: CGFloat?, alignment: Alignment) -> some View {
            Rectangle()
                .fill(NativeEditorTableLayout.selectionAccent)
                .frame(width: width, height: height)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
                .allowsHitTesting(false)
    }
}
