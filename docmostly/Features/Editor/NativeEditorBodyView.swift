import SwiftUI

struct NativeEditorBodyView: View {
    @Bindable var viewModel: NativeRichEditorViewModel
    let focusedField: FocusState<NativeEditorFocus?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Page title", text: $viewModel.title, axis: .vertical)
                .font(.largeTitle)
                .bold()
                .textFieldStyle(.plain)
                .focused(focusedField, equals: .title)
                .accessibilityLabel("Page title")

            if let saveErrorMessage = viewModel.saveErrorMessage {
                NativeEditorSaveErrorView(message: saveErrorMessage)
            }

            NativeEditorCollaborationStatusView(viewModel: viewModel)

            ForEach($viewModel.document.blocks) { $block in
                VStack(alignment: .leading, spacing: 6) {
                    NativeEditorBlockRow(
                        block: $block,
                        focusedField: focusedField,
                        isSelected: viewModel.selectedBlockID == block.id,
                        isShowingControls: viewModel.visibleBlockControlsID == block.id,
                        select: { viewModel.selectBlock(block.id) },
                        showControls: { viewModel.showBlockControls(for: block.id) },
                        insertBelow: { viewModel.insertBlock(after: block.id) },
                        delete: { viewModel.deleteBlock(block.id) },
                        tableActions: tableEditingActions,
                        richBlockActions: richBlockEditingActions,
                        moveBefore: { movedBlockID in
                            viewModel.moveBlock(movedBlockID, before: block.id)
                        },
                        dropText: { text in
                            viewModel.dropMarkdown(text, before: block.id)
                        }
                    )

                    if viewModel.selectedBlockID == block.id {
                        NativeEditorBlockSelectionBar(delete: viewModel.deleteSelectedBlock)
                    }

                    if viewModel.activeBlockID == block.id, viewModel.isShowingSlashCommands {
                        NativeEditorSlashCommandMenu(viewModel: viewModel)
                            .padding(.leading, 34)
                    }
                }
            }

            Button("Add Block", systemImage: "plus", action: viewModel.appendBlock)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
        }
        .onChange(of: viewModel.document) {
            viewModel.handleDocumentChanged()
        }
        .onChange(of: viewModel.title) {
            viewModel.handleTitleChanged()
        }
        .onChange(of: viewModel.activeBlockID) { _, blockID in
            guard let blockID else { return }
            focusedField.wrappedValue = .block(blockID)
        }
    }

    private var tableEditingActions: NativeEditorTableEditingActions {
        NativeEditorTableEditingActions(
            updateCell: { blockID, rowIndex, columnIndex, text in
                viewModel.updateTableCell(
                    blockID: blockID,
                    rowIndex: rowIndex,
                    columnIndex: columnIndex,
                    text: text
                )
            },
            insertRowBelow: viewModel.insertTableRowBelow,
            deleteRow: viewModel.deleteTableRow,
            insertColumnAfter: viewModel.insertTableColumnAfter,
            deleteColumn: viewModel.deleteTableColumn
        )
    }

    private var richBlockEditingActions: NativeEditorRichBlockEditingActions {
        NativeEditorRichBlockEditingActions(
            updateCallout: viewModel.updateCallout,
            updateDetails: viewModel.updateDetails,
            updateEmbed: viewModel.updateEmbed,
            updateMathBlock: viewModel.updateMathBlock
        )
    }
}
