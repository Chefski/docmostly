import SwiftUI

struct NativeEditorBodyView: View {
    @Bindable var viewModel: NativeRichEditorViewModel
    let focusedField: FocusState<NativeEditorFocus?>.Binding
    var isAuthoringEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Page title", text: $viewModel.title, axis: .vertical)
                .font(.largeTitle)
                .bold()
                .textFieldStyle(.plain)
                .focused(focusedField, equals: .title)
                .disabled(authoringIsAvailable == false)
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
                        isReadOnly: authoringIsAvailable == false,
                        select: {
                            guard authoringIsAvailable else { return }
                            viewModel.selectBlock(block.id)
                        },
                        showControls: {
                            guard authoringIsAvailable else { return }
                            viewModel.showBlockControls(for: block.id)
                        },
                        insertBelow: {
                            guard authoringIsAvailable else { return }
                            viewModel.insertBlock(after: block.id)
                        },
                        delete: {
                            guard authoringIsAvailable else { return }
                            viewModel.deleteBlock(block.id)
                        },
                        tableActions: authoringIsAvailable ? tableEditingActions : nil,
                        richBlockActions: authoringIsAvailable ? richBlockEditingActions : nil,
                        pageID: viewModel.currentPageID,
                        spaceID: viewModel.currentSpaceID,
                        moveBefore: { movedBlockID in
                            guard authoringIsAvailable else { return }
                            viewModel.moveBlock(movedBlockID, before: block.id)
                        },
                        selectionChanged: {
                            guard authoringIsAvailable else { return }
                            viewModel.handleLocalSelectionChanged()
                        },
                        dropText: { text in
                            guard authoringIsAvailable else { return false }
                            return viewModel.dropMarkdown(text, before: block.id)
                        }
                    )
                    .id(block.id)

                    if authoringIsAvailable, viewModel.selectedBlockID == block.id {
                        NativeEditorBlockSelectionBar(delete: viewModel.deleteSelectedBlock)
                    }

                    if authoringIsAvailable, viewModel.activeBlockID == block.id, viewModel.isShowingSlashCommands {
                        NativeEditorSlashCommandMenu(viewModel: viewModel)
                            .padding(.leading, 34)
                    }

                    let remoteCursors = viewModel.resolvedCursorsForBlock(id: block.id)
                    if remoteCursors.isEmpty == false {
                        NativeEditorRemoteCursorBadgeStack(cursors: remoteCursors)
                            .padding(.leading, 34)
                    }
                }
            }

            if authoringIsAvailable {
                Button("Add Block", systemImage: "plus", action: viewModel.appendBlock)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
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

    private var authoringIsAvailable: Bool {
        isAuthoringEnabled && viewModel.canEdit
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
            insertRowAbove: viewModel.insertTableRowAbove,
            insertRowBelow: viewModel.insertTableRowBelow,
            deleteRow: viewModel.deleteTableRow,
            insertColumnBefore: viewModel.insertTableColumnBefore,
            insertColumnAfter: viewModel.insertTableColumnAfter,
            deleteColumn: viewModel.deleteTableColumn,
            updateColumnWidth: viewModel.updateTableColumnWidth
        )
    }

    private var richBlockEditingActions: NativeEditorRichBlockEditingActions {
        NativeEditorRichBlockEditingActions(
            updateCallout: viewModel.updateCallout,
            updateDetails: viewModel.updateDetails,
            updateColumns: viewModel.updateColumns,
            updateTransclusionSource: viewModel.updateTransclusionSource,
            updateTransclusionReference: viewModel.updateTransclusionReference,
            updateMediaBlock: viewModel.updateMediaBlock,
            updatePDFBlock: viewModel.updatePDFBlock,
            updateAttachmentBlock: viewModel.updateAttachmentBlock,
            updateEmbed: viewModel.updateEmbed,
            updateDrawio: viewModel.updateDrawio,
            updateExcalidraw: viewModel.updateExcalidraw,
            updateMathBlock: viewModel.updateMathBlock
        )
    }
}
