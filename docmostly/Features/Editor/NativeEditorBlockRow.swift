import SwiftUI

struct NativeEditorBlockRow: View {
    @Binding var block: NativeEditorBlock
    let isActive: Bool
    let focusRequestID: UUID?
    let retainsResponderDuringFocusHandoff: Bool
    let isSelected: Bool
    let isShowingControls: Bool
    let isReadOnly: Bool
    let select: () -> Void
    let showControls: () -> Void
    let insertBelow: () -> Void
    let delete: () -> Void
    let tableActions: NativeEditorTableEditingActions?
    let richBlockActions: NativeEditorRichBlockEditingActions?
    let pageID: String
    let spaceID: String?
    let serverURLString: String?
    let remotePresenceSegments: [NativeEditorRemotePresenceSegment]
    let presenceProjection: NativeEditorRemotePresenceProjection
    let presenceScope: [NativeEditorRemotePresenceScope]
    let presenceBlockIndex: Int
    let textInputFocusChanged: (Bool) -> Void
    let typingInlineMarks: Set<NativeEditorInlineMark>
    let invalidateInlineTypingContext: () -> Void
    let moveBefore: (UUID) -> Void
    let splitBlock: (Range<Int>) -> Bool
    let insertHardBreak: (Range<Int>) -> Bool
    let mergeBlockBackward: () -> Bool
    let blockChanged: () -> Void
    let selectionChanged: () -> Void
    let dropText: (String) -> Bool

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if showsControls {
                VStack(spacing: 4) {
                    Button(
                        "Select Block",
                        systemImage: isSelected ? "checkmark.square" : "square.dashed",
                        action: select
                    )
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(isSelected ? DocmostlyTheme.primary : .secondary)
                        .frame(width: 44, height: 44)
                        .draggable(block.id.uuidString)

                    if hasVisiblePrefix {
                        NativeEditorBlockPrefix(
                            block: $block,
                            allowsTaskToggle: NativeEditorBlockRowPolicy.allowsTaskToggle(isReadOnly: isReadOnly)
                        )
                            .frame(width: 24, alignment: .center)
                    }
                }
            } else if hasVisiblePrefix {
                NativeEditorBlockPrefix(
                    block: $block,
                    allowsTaskToggle: NativeEditorBlockRowPolicy.allowsTaskToggle(isReadOnly: isReadOnly)
                )
                    .frame(width: 24, alignment: .center)
            }

            if usesTextInputSurface {
                NativeEditorBlockTextSurface(kind: block.kind) {
                    NativeEditorTextInputView(
                        block: $block,
                        isEditable: isReadOnly == false,
                        isFocused: isActive,
                        focusRequestID: focusRequestID,
                        retainsResponderDuringFocusHandoff: retainsResponderDuringFocusHandoff,
                        focusChanged: textInputFocusChanged,
                        typingInlineMarks: typingInlineMarks,
                        invalidateTypingContext: invalidateInlineTypingContext,
                        accessibilityLabel: block.kind.accessibilityLabel,
                        actions: NativeEditorTextInputActions(
                            handleReturn: handleReturn,
                            insertHardBreak: insertHardBreak,
                            mergeBlockBackward: mergeBlockBackward
                        ),
                        remotePresenceSegments: remotePresenceSegments
                    )
                        .frame(maxWidth: .infinity, minHeight: minimumEditorHeight, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .onChange(of: block.selection) { _, _ in
                            selectionChanged()
                        }
                }
            } else {
                NativeEditorRichBlockPreviewView(
                    block: block,
                    tableActions: tableActions,
                    richBlockActions: activeRichBlockActions,
                    pageID: pageID,
                    spaceID: spaceID,
                    serverURLString: serverURLString,
                    presenceProjection: presenceProjection,
                    presenceScope: presenceScope,
                    presenceBlockIndex: presenceBlockIndex
                )
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if showsControls {
                Menu {
                    Button("Insert Below", systemImage: "plus", action: insertBelow)
                    Button("Delete Block", systemImage: "trash", role: .destructive, action: delete)
                } label: {
                    Label("Block Actions", systemImage: "ellipsis")
                }
                .labelStyle(.iconOnly)
                .menuStyle(.button)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, rowVerticalPadding)
        .padding(.leading, blockIndentPadding)
        .background {
            (isSelected ? DocmostlyTheme.primaryTint : Color.clear)
                .clipShape(.rect(cornerRadius: 8))
                .contentShape(.rect)
                .onLongPressGesture {
                    guard isReadOnly == false else { return }
                    showControls()
                }
        }
        .dropDestination(for: String.self) { blockIDs, _ in
            guard isReadOnly == false else { return false }
            guard let rawBlockID = blockIDs.first else { return false }
            let movedBlockID = UUID(uuidString: rawBlockID)

            if let movedBlockID {
                moveBefore(movedBlockID)
                return true
            }

            return dropText(rawBlockID)
        }
        .contextMenu {
            if isReadOnly == false {
                Button("Select Block", systemImage: "checkmark.square", action: select)
                Button("Insert Below", systemImage: "plus", action: insertBelow)
                Divider()
                Button("Delete Block", systemImage: "trash", role: .destructive, action: delete)
            }
        }
        #if os(macOS)
        .onDeleteCommand {
            guard isReadOnly == false, isSelected else { return }
            delete()
        }
        #endif
        .accessibilityAction(named: "Show Block Actions") {
            guard isReadOnly == false else { return }
            showControls()
        }
        .accessibilityAction(named: "Insert Block Below") {
            guard isReadOnly == false else { return }
            insertBelow()
        }
        .accessibilityAction(named: "Delete Block") {
            guard isReadOnly == false else { return }
            delete()
        }
        .onChange(of: block) { _, _ in
            blockChanged()
        }
    }

    private var minimumEditorHeight: CGFloat {
        guard block.text.characters.isEmpty else {
            return 0
        }

        return switch block.kind {
        case .heading:
            44
        case .codeBlock:
            76
        default:
            28
        }
    }

    private var usesTextInputSurface: Bool {
        NativeEditorBlockRowPolicy.usesTextInputSurface(block: block)
    }

    private var showsControls: Bool {
        isReadOnly == false && (isShowingControls || isSelected)
    }

    private var hasVisiblePrefix: Bool {
        NativeEditorBlockRowPolicy.hasVisiblePrefix(kind: block.kind)
    }

    private var blockIndentPadding: CGFloat {
        CGFloat(block.indentLevel) * 22
    }

    private var rowVerticalPadding: CGFloat {
        switch block.kind {
        case .bulletListItem, .orderedListItem, .taskListItem:
            0
        case .divider:
            6
        default:
            2
        }
    }

    private var activeRichBlockActions: NativeEditorRichBlockEditingActions? {
        showsControls ? richBlockActions : nil
    }

    private func handleReturn(_ selection: Range<Int>) -> Bool {
        switch NativeEditorReturnKeyBehavior.resolve(
            kind: block.kind,
            text: block.text,
            selection: selection
        ) {
        case .splitBlock:
            splitBlock(selection)
        case .insertHardBreak:
            insertHardBreak(selection)
        }
    }
}
