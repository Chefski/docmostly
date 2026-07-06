import SwiftUI

struct NativeEditorTableActionBar: View {
    let blockID: UUID
    let table: NativeEditorTable
    let actions: NativeEditorTableEditingActions
    let selection: NativeEditorTableSelection?
    @Binding var actionSelection: NativeEditorTableSelection?
    @Binding var isShowingActionDialog: Bool

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            DocmostlyGlassPanel(cornerRadius: 14) {
                HStack(spacing: 8) {
                    if let selection {
                        Text(selection.summaryTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .padding(.trailing, 2)

                        NativeEditorTableInlineButtons(
                            blockID: blockID,
                            table: table,
                            actions: actions,
                            selection: selection,
                            showMore: showActions
                        )
                        .labelStyle(.iconOnly)
                    } else {
                        Button("Add row", systemImage: "arrow.down.to.line") {
                            actions.insertRowBelow(blockID, max(table.rows.count - 1, 0))
                        }
                        .help("Add row")

                        Button("Add column", systemImage: "arrow.right.to.line") {
                            actions.insertColumnAfter(blockID, max(table.columnCount - 1, 0))
                        }
                        .help("Add column")
                    }
                }
                .buttonStyle(NativeEditorTableToolbarButtonStyle())
                .controlSize(.small)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
    }

    private func showActions(_ selection: NativeEditorTableSelection) {
        actionSelection = selection
        isShowingActionDialog = true
    }
}

private struct NativeEditorTableToolbarButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .foregroundStyle(.primary)
            .padding(.horizontal, 8)
            .frame(minHeight: 28)
            .background(backgroundColor(isPressed: configuration.isPressed), in: .capsule)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        isPressed ? DocmostlyTheme.primaryTint : Color.secondary.opacity(0.08)
    }
}

private struct NativeEditorTableInlineButtons: View {
    let blockID: UUID
    let table: NativeEditorTable
    let actions: NativeEditorTableEditingActions
    let selection: NativeEditorTableSelection
    let showMore: (NativeEditorTableSelection) -> Void

    var body: some View {
        switch selection.kind {
        case .cell:
            NativeEditorTableCellInlineButtons(
                blockID: blockID,
                actions: actions,
                selection: selection,
                showMore: showMore
            )
        case .row:
            NativeEditorTableRowInlineButtons(
                blockID: blockID,
                table: table,
                actions: actions,
                selection: selection,
                showMore: showMore
            )
        case .column:
            NativeEditorTableColumnInlineButtons(
                blockID: blockID,
                table: table,
                actions: actions,
                selection: selection,
                showMore: showMore
            )
        }
    }
}

private struct NativeEditorTableCellInlineButtons: View {
    let blockID: UUID
    let actions: NativeEditorTableEditingActions
    let selection: NativeEditorTableSelection
    let showMore: (NativeEditorTableSelection) -> Void

    var body: some View {
        if let rowIndex = selection.rowIndex {
            Button("Add row below", systemImage: "arrow.down.to.line") {
                actions.insertRowBelow(blockID, rowIndex)
            }
            .help("Add row below")
        }

        if let columnIndex = selection.columnIndex {
            Button("Add column right", systemImage: "arrow.right.to.line") {
                actions.insertColumnAfter(blockID, columnIndex)
            }
            .help("Add column right")
        }

        Button("More table actions", systemImage: "ellipsis") {
            showMore(selection)
        }
        .help("More table actions")
    }
}

private struct NativeEditorTableRowInlineButtons: View {
    let blockID: UUID
    let table: NativeEditorTable
    let actions: NativeEditorTableEditingActions
    let selection: NativeEditorTableSelection
    let showMore: (NativeEditorTableSelection) -> Void

    var body: some View {
        if let rowIndex = selection.rowIndex {
            Button("Add row above", systemImage: "arrow.up.to.line") {
                actions.insertRowAbove(blockID, rowIndex)
            }
            .help("Add row above")

            Button("Add row below", systemImage: "arrow.down.to.line") {
                actions.insertRowBelow(blockID, rowIndex)
            }
            .help("Add row below")

            Button("Delete row", systemImage: "trash", role: .destructive) {
                actions.deleteRow(blockID, rowIndex)
            }
            .disabled(table.rows.count <= 1)
            .help("Delete row")
        }

        Button("More row actions", systemImage: "ellipsis") {
            showMore(selection)
        }
        .help("More row actions")
    }
}

private struct NativeEditorTableColumnInlineButtons: View {
    let blockID: UUID
    let table: NativeEditorTable
    let actions: NativeEditorTableEditingActions
    let selection: NativeEditorTableSelection
    let showMore: (NativeEditorTableSelection) -> Void

    var body: some View {
        if let columnIndex = selection.columnIndex {
            Button("Add column left", systemImage: "arrow.left.to.line") {
                actions.insertColumnBefore(blockID, columnIndex)
            }
            .help("Add column left")

            Button("Add column right", systemImage: "arrow.right.to.line") {
                actions.insertColumnAfter(blockID, columnIndex)
            }
            .help("Add column right")

            Button("Delete column", systemImage: "trash", role: .destructive) {
                actions.deleteColumn(blockID, columnIndex)
            }
            .disabled(table.columnCount <= 1)
            .help("Delete column")
        }

        Button("More column actions", systemImage: "ellipsis") {
            showMore(selection)
        }
        .help("More column actions")
    }
}

struct NativeEditorTableDialogActions: View {
    let blockID: UUID
    let table: NativeEditorTable
    let selection: NativeEditorTableSelection
    let actions: NativeEditorTableEditingActions

    var body: some View {
        switch selection.kind {
        case .cell:
            NativeEditorTableCellDialogActions(blockID: blockID, selection: selection, actions: actions)
        case .row:
            NativeEditorTableRowDialogActions(blockID: blockID, table: table, selection: selection, actions: actions)
        case .column:
            NativeEditorTableColumnDialogActions(blockID: blockID, table: table, selection: selection, actions: actions)
        }
    }
}

private struct NativeEditorTableCellDialogActions: View {
    let blockID: UUID
    let selection: NativeEditorTableSelection
    let actions: NativeEditorTableEditingActions

    var body: some View {
        if let rowIndex = selection.rowIndex {
            Button("Add row above", systemImage: "arrow.up.to.line") {
                actions.insertRowAbove(blockID, rowIndex)
            }

            Button("Add row below", systemImage: "arrow.down.to.line") {
                actions.insertRowBelow(blockID, rowIndex)
            }
        }

        if let columnIndex = selection.columnIndex {
            Button("Add column left", systemImage: "arrow.left.to.line") {
                actions.insertColumnBefore(blockID, columnIndex)
            }

            Button("Add column right", systemImage: "arrow.right.to.line") {
                actions.insertColumnAfter(blockID, columnIndex)
            }
        }

        if let rowIndex = selection.rowIndex, let columnIndex = selection.columnIndex {
            Button("Clear cell", systemImage: "eraser") {
                actions.updateCell(blockID, rowIndex, columnIndex, "")
            }
        }
    }
}

private struct NativeEditorTableRowDialogActions: View {
    let blockID: UUID
    let table: NativeEditorTable
    let selection: NativeEditorTableSelection
    let actions: NativeEditorTableEditingActions

    var body: some View {
        if let rowIndex = selection.rowIndex {
            Button("Add row above", systemImage: "arrow.up.to.line") {
                actions.insertRowAbove(blockID, rowIndex)
            }

            Button("Add row below", systemImage: "arrow.down.to.line") {
                actions.insertRowBelow(blockID, rowIndex)
            }

            Button("Delete row", systemImage: "trash", role: .destructive) {
                actions.deleteRow(blockID, rowIndex)
            }
            .disabled(table.rows.count <= 1)
        }
    }
}

private struct NativeEditorTableColumnDialogActions: View {
    let blockID: UUID
    let table: NativeEditorTable
    let selection: NativeEditorTableSelection
    let actions: NativeEditorTableEditingActions

    var body: some View {
        if let columnIndex = selection.columnIndex {
            Button("Add column left", systemImage: "arrow.left.to.line") {
                actions.insertColumnBefore(blockID, columnIndex)
            }

            Button("Add column right", systemImage: "arrow.right.to.line") {
                actions.insertColumnAfter(blockID, columnIndex)
            }

            Button("Delete column", systemImage: "trash", role: .destructive) {
                actions.deleteColumn(blockID, columnIndex)
            }
            .disabled(table.columnCount <= 1)
        }
    }
}

struct NativeEditorEmptyTableView: View {
    var body: some View {
        Label("Empty table", systemImage: "tablecells")
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .overlay {
                Rectangle()
                    .stroke(NativeEditorTableLayout.outerBorderStyle, lineWidth: 1)
            }
    }
}

struct NativeEditorEditableEmptyTableView: View {
    let blockID: UUID
    let actions: NativeEditorTableEditingActions

    var body: some View {
        HStack(spacing: 8) {
            Label("Empty table", systemImage: "tablecells")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Button("Add row", systemImage: "arrow.down.to.line") {
                actions.insertRowBelow(blockID, 0)
            }

            Button("Add column", systemImage: "arrow.right.to.line") {
                actions.insertColumnAfter(blockID, 0)
            }
        }
        .buttonStyle(NativeEditorTableToolbarButtonStyle())
        .padding()
        .overlay {
            Rectangle()
                .stroke(NativeEditorTableLayout.outerBorderStyle, lineWidth: 1)
        }
    }
}
