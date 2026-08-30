import SwiftUI

struct NativeEditorBodyView: View {
    @State private var textInputFocusRequest: NativeEditorTextInputFocusRequest?
    @State private var pendingBlockRemoval: PendingBlockRemoval?
    @Bindable var viewModel: NativeRichEditorViewModel
    let focusedField: FocusState<NativeEditorFocus?>.Binding
    var isAuthoringEnabled = true
    var serverURLString: String?
    var importAttachment: (NativeEditorAttachmentImportKind) -> Void = { _ in }
    var applyCommand: ((NativeEditorCommand) -> Void)?
    var applyPendingRemoteUpdate: (() -> Void)?
    var keepPendingLocalUpdate: (() -> Void)?
    var pickPageEmoji: (() -> Void)?
    var slashCommandFilter: (NativeEditorCommand) -> Bool = { _ in true }
    var showsTitle = true
    var showsCollaborationStatus = true
    var presenceProjection: NativeEditorRemotePresenceProjection?
    var presenceScope: [NativeEditorRemotePresenceScope] = []

    var body: some View {
        LazyVStack(alignment: .leading, spacing: 6) {
            if showsTitle {
                HStack(alignment: .firstTextBaseline) {
                    if let pickPageEmoji {
                        NativeEditorPageTitleIconButton(icon: viewModel.icon, action: pickPageEmoji)
                            .disabled(authoringIsAvailable == false)
                    }

                    TextField("Page title", text: $viewModel.title, axis: .vertical)
                        .font(.largeTitle)
                        .bold()
                        .textFieldStyle(.plain)
                        .focused(focusedField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit(advanceFromTitle)
                        .disabled(authoringIsAvailable == false)
                        .accessibilityLabel("Page title")
                }

                if let creatorName = viewModel.creator?.name, creatorName.isEmpty == false {
                    NativeEditorBylineView(authorName: creatorName)
                }
            }

            if let saveErrorMessage = viewModel.saveErrorMessage {
                NativeEditorSaveErrorView(message: saveErrorMessage)
            }

            if showsCollaborationStatus {
                NativeEditorCollaborationStatusView(
                    viewModel: viewModel,
                    applyPendingRemoteUpdate: applyPendingRemoteUpdate,
                    keepPendingLocalUpdate: keepPendingLocalUpdate
                )
            }

            ForEach($viewModel.document.blocks) { $block in
                VStack(alignment: .leading, spacing: 6) {
                    NativeEditorBlockRow(
                        block: $block,
                        isActive: viewModel.activeBlockID == block.id,
                        focusRequestID: textInputFocusRequest?.blockID == block.id
                            ? textInputFocusRequest?.id
                            : nil,
                        retainsResponderDuringFocusHandoff: viewModel.activeBlockID != nil &&
                            viewModel.activeBlockID != block.id,
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
                            requestActiveBlockFocus()
                        },
                        delete: {
                            guard authoringIsAvailable else { return }
                            deleteBlockPreservingFocus(block.id)
                        },
                        tableActions: authoringIsAvailable ? tableEditingActions : nil,
                        richBlockActions: authoringIsAvailable ? richBlockEditingActions : nil,
                        pageID: viewModel.currentPageID,
                        spaceID: viewModel.currentSpaceID,
                        serverURLString: serverURLString,
                        remotePresenceSegments: remotePresenceSegments(for: block.id),
                        presenceProjection: activePresenceProjection,
                        presenceScope: presenceScope,
                        presenceBlockIndex: blockIndex(for: block.id),
                        textInputFocusChanged: { isFocused in
                            if isFocused {
                                guard authoringIsAvailable else { return }
                                viewModel.textInputDidBeginEditing(blockID: block.id)
                                completePendingBlockRemoval(focusedBlockID: block.id)
                            } else {
                                viewModel.textInputDidEndEditing(blockID: block.id)
                            }
                        },
                        typingInlineMarks: viewModel.typingInlineMarks(for: block.id),
                        invalidateInlineTypingContext: {
                            viewModel.invalidateInlineTypingContext(for: block.id)
                        },
                        moveBefore: { movedBlockID in
                            guard authoringIsAvailable else { return }
                            viewModel.moveBlock(movedBlockID, before: block.id)
                        },
                        splitBlock: { characterRange in
                            guard authoringIsAvailable else { return false }
                            guard let continuationBlockID = viewModel.splitBlock(
                                block.id,
                                replacing: characterRange
                            ) else {
                                return false
                            }
                            requestBlockFocus(continuationBlockID)
                            return true
                        },
                        insertHardBreak: { characterRange in
                            guard authoringIsAvailable else { return false }
                            return viewModel.insertSoftBreak(in: block.id, replacing: characterRange)
                        },
                        mergeBlockBackward: {
                            guard authoringIsAvailable else { return false }
                            return mergeBlockBackwardPreservingFocus(block.id)
                        },
                        blockChanged: {
                            guard authoringIsAvailable else { return }
                            viewModel.handleDocumentChanged()
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
                        NativeEditorBlockSelectionBar(delete: deleteSelectedBlock)
                    }

                    if authoringIsAvailable, viewModel.activeBlockID == block.id, viewModel.isShowingSlashCommands {
                        NativeEditorSlashCommandMenu(
                            viewModel: viewModel,
                            importAttachment: importAttachment,
                            applyCommand: applyCommand,
                            commandFilter: slashCommandFilter
                        )
                            .padding(.leading, 34)
                    }

                }
            }

            if authoringIsAvailable {
                Button("Add Block", systemImage: "plus", action: appendBlock)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: viewModel.title) {
            viewModel.handleTitleChanged()
        }
        .onChange(of: viewModel.activeBlockID) { _, blockID in
            guard let blockID else {
                textInputFocusRequest = nil
                pendingBlockRemoval = nil
                return
            }
            if pendingBlockRemoval?.destinationBlockID != blockID {
                pendingBlockRemoval = nil
            }
            guard viewModel.focusedTextInputBlockID != blockID else { return }
            guard textInputFocusRequest?.blockID != blockID else { return }
            enqueueBlockFocusRequest(blockID)
        }
    }

    private var authoringIsAvailable: Bool {
        isAuthoringEnabled && viewModel.canEdit && viewModel.isResolvingConflict == false
    }

    private var activePresenceProjection: NativeEditorRemotePresenceProjection {
        presenceProjection ?? viewModel.remotePresenceProjection
    }

    private func blockIndex(for blockID: UUID) -> Int {
        viewModel.document.blocks.firstIndex(where: { $0.id == blockID }) ?? 0
    }

    private func remotePresenceSegments(for blockID: UUID) -> [NativeEditorRemotePresenceSegment] {
        activePresenceProjection.segments(
            scope: presenceScope,
            blockIndex: blockIndex(for: blockID)
        )
    }

    private func advanceFromTitle() {
        guard authoringIsAvailable else { return }
        if let firstEditableBlock = viewModel.document.blocks.first(where: \.isEditable) {
            requestBlockFocus(firstEditableBlock.id)
        } else {
            appendBlock()
        }
    }

    private func requestBlockFocus(_ blockID: UUID) {
        guard
            authoringIsAvailable,
            viewModel.document.blocks.contains(where: { $0.id == blockID && $0.isEditable })
        else {
            return
        }

        viewModel.focus(blockID: blockID)
        enqueueBlockFocusRequest(blockID)
    }

    private func enqueueBlockFocusRequest(_ blockID: UUID) {
        textInputFocusRequest = NativeEditorTextInputFocusRequest(blockID: blockID)

        Task { @MainActor in
            await Task.yield()
            guard
                authoringIsAvailable,
                viewModel.activeBlockID == blockID,
                viewModel.document.blocks.contains(where: { $0.id == blockID && $0.isEditable })
            else {
                return
            }
            textInputFocusRequest = NativeEditorTextInputFocusRequest(blockID: blockID)

            try? await Task.sleep(for: .milliseconds(250))
            guard
                authoringIsAvailable,
                viewModel.activeBlockID == blockID,
                viewModel.focusedTextInputBlockID != blockID,
                viewModel.document.blocks.contains(where: { $0.id == blockID && $0.isEditable })
            else {
                return
            }
            textInputFocusRequest = NativeEditorTextInputFocusRequest(blockID: blockID)
        }
    }

    private func requestActiveBlockFocus() {
        guard let activeBlockID = viewModel.activeBlockID else { return }
        requestBlockFocus(activeBlockID)
    }

    private func appendBlock() {
        viewModel.appendBlock()
        requestActiveBlockFocus()
    }

    private func deleteSelectedBlock() {
        guard let destinationBlockID = viewModel.deleteSelectedBlock() else { return }
        requestBlockFocus(destinationBlockID)
    }

    private func deleteBlockPreservingFocus(_ blockID: UUID) {
        guard let destinationBlockID = viewModel.deletionFocusDestination(for: blockID) else { return }
        guard viewModel.focusedTextInputBlockID == blockID, destinationBlockID != blockID else {
            guard viewModel.deleteBlock(blockID) != nil else { return }
            requestBlockFocus(destinationBlockID)
            return
        }

        pendingBlockRemoval = .deletion(
            sourceBlockID: blockID,
            destinationBlockID: destinationBlockID
        )
        requestBlockFocus(destinationBlockID)
    }

    private func mergeBlockBackwardPreservingFocus(_ blockID: UUID) -> Bool {
        guard let destinationBlockID = viewModel.backwardMergeDestination(for: blockID) else { return false }

        pendingBlockRemoval = .backwardMerge(
            sourceBlockID: blockID,
            destinationBlockID: destinationBlockID
        )
        requestBlockFocus(destinationBlockID)
        return true
    }

    private func completePendingBlockRemoval(focusedBlockID: UUID) {
        guard
            authoringIsAvailable,
            let pendingBlockRemoval,
            pendingBlockRemoval.destinationBlockID == focusedBlockID
        else {
            return
        }

        self.pendingBlockRemoval = nil
        let destinationBlockID: UUID?
        switch pendingBlockRemoval {
        case .deletion(let sourceBlockID, _):
            destinationBlockID = viewModel.deleteBlock(sourceBlockID)
        case .backwardMerge(let sourceBlockID, let expectedDestinationBlockID):
            destinationBlockID = viewModel.mergeBlockBackward(sourceBlockID)
                ? expectedDestinationBlockID
                : nil
        }
        guard let destinationBlockID else { return }
        requestBlockFocus(destinationBlockID)
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
            updateNestedContent: viewModel.updateNestedContent,
            setColumnCount: viewModel.setColumnCount,
            updateColumnWidth: viewModel.updateColumnWidth,
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

private extension NativeEditorBodyView {
    enum PendingBlockRemoval: Equatable {
        case deletion(sourceBlockID: UUID, destinationBlockID: UUID)
        case backwardMerge(sourceBlockID: UUID, destinationBlockID: UUID)

        var destinationBlockID: UUID {
            switch self {
            case .deletion(_, let destinationBlockID), .backwardMerge(_, let destinationBlockID):
                destinationBlockID
            }
        }
    }
}

private struct NativeEditorTextInputFocusRequest {
    let id = UUID()
    let blockID: UUID
}
