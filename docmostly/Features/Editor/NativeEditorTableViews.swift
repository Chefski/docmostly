import SwiftUI

struct NativeEditorTablePreview: View {
    let table: NativeEditorTable

    var body: some View {
        VStack(spacing: 0) {
            let visibleRows = table.rows.prefix(3)
            ForEach(visibleRows.indices, id: \.self) { rowIndex in
                let row = table.rows[rowIndex]
                HStack(spacing: 0) {
                    let visibleCells = row.cells.prefix(3)
                    ForEach(visibleCells.indices, id: \.self) { cellIndex in
                        let cell = row.cells[cellIndex]
                        Text(cell.plainText.isEmpty ? " " : cell.plainText)
                            .font(cell.isHeader ? .subheadline.bold() : .subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(cell.isHeader ? Color.secondary.opacity(0.12) : Color.clear)
                            .overlay(alignment: .trailing) {
                                Divider()
                            }
                    }
                }
                .overlay(alignment: .bottom) {
                    Divider()
                }
            }
        }
        .clipShape(.rect(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(.quaternary, lineWidth: 1)
        }
    }
}

struct NativeEditorTableEditor: View {
    let blockID: UUID
    let table: NativeEditorTable
    let actions: NativeEditorTableEditingActions

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal) {
                Grid(horizontalSpacing: 0, verticalSpacing: 0) {
                    ForEach(table.rows.indices, id: \.self) { rowIndex in
                        tableRow(rowIndex)
                    }

                    tableColumnControls
                }
                .clipShape(.rect(cornerRadius: 6))
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.quaternary, lineWidth: 1)
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func tableRow(_ rowIndex: Int) -> some View {
        GridRow {
            ForEach(0..<columnCount, id: \.self) { columnIndex in
                if let cell = cell(rowIndex: rowIndex, columnIndex: columnIndex) {
                    tableCell(cell, rowIndex: rowIndex, columnIndex: columnIndex)
                } else {
                    missingCell
                }
            }

            rowControls(rowIndex)
        }
    }

    private func tableCell(
        _ cell: NativeEditorTableCell,
        rowIndex: Int,
        columnIndex: Int
    ) -> some View {
        TextField("Cell", text: cellBinding(rowIndex: rowIndex, columnIndex: columnIndex), axis: .vertical)
            .textFieldStyle(.plain)
            .font(cell.isHeader ? .subheadline.bold() : .subheadline)
            .foregroundStyle(.primary)
            .lineLimit(3)
            .frame(width: 148, alignment: .leading)
            .frame(minHeight: 44, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(cellBackground(for: cell))
            .overlay(alignment: .trailing) {
                Divider()
            }
            .overlay(alignment: .bottom) {
                Divider()
            }
    }

    private func rowControls(_ rowIndex: Int) -> some View {
        HStack(spacing: 2) {
            Button("Add Row Below", systemImage: "plus") {
                actions.insertRowBelow(blockID, rowIndex)
            }
            .accessibilityLabel("Add row below")

            Button("Delete Row", systemImage: "trash", role: .destructive) {
                actions.deleteRow(blockID, rowIndex)
            }
            .accessibilityLabel("Delete row")
            .disabled(table.rows.count <= 1)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .controlSize(.small)
        .frame(width: 72)
        .frame(minHeight: 44)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var tableColumnControls: some View {
        GridRow {
            ForEach(0..<columnCount, id: \.self) { columnIndex in
                HStack(spacing: 2) {
                    Button("Add Column After", systemImage: "plus") {
                        actions.insertColumnAfter(blockID, columnIndex)
                    }
                    .accessibilityLabel("Add column after")

                    Button("Delete Column", systemImage: "trash", role: .destructive) {
                        actions.deleteColumn(blockID, columnIndex)
                    }
                    .accessibilityLabel("Delete column")
                    .disabled(columnCount <= 1)
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .controlSize(.small)
                .frame(width: 148)
                .frame(minHeight: 36)
                .background(Color.secondary.opacity(0.05))
                .overlay(alignment: .trailing) {
                    Divider()
                }
            }

            Color.clear
                .frame(width: 72)
                .frame(minHeight: 36)
                .background(Color.secondary.opacity(0.05))
        }
    }

    private var missingCell: some View {
        Text(" ")
            .frame(width: 148)
            .frame(minHeight: 44)
            .background(Color.secondary.opacity(0.04))
            .overlay(alignment: .trailing) {
                Divider()
            }
            .overlay(alignment: .bottom) {
                Divider()
            }
    }

    private var columnCount: Int {
        max(table.columnCount, 1)
    }

    private func cell(rowIndex: Int, columnIndex: Int) -> NativeEditorTableCell? {
        guard table.rows.indices.contains(rowIndex),
              table.rows[rowIndex].cells.indices.contains(columnIndex) else {
            return nil
        }

        return table.rows[rowIndex].cells[columnIndex]
    }

    private func cellBinding(rowIndex: Int, columnIndex: Int) -> Binding<String> {
        Binding {
            cell(rowIndex: rowIndex, columnIndex: columnIndex)?.plainText ?? ""
        } set: { text in
            actions.updateCell(blockID, rowIndex, columnIndex, text)
        }
    }

    private func cellBackground(for cell: NativeEditorTableCell) -> Color {
        cell.isHeader ? Color.secondary.opacity(0.12) : Color.clear
    }
}
