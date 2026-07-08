import SwiftUI

struct NativeEditorBlockRow: View {
    @Binding var block: NativeEditorBlock
    let focusedField: FocusState<NativeEditorFocus?>.Binding
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
    let focusBlock: () -> Void
    let moveBefore: (UUID) -> Void
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

            if showsEditableTextEditor {
                NativeEditorBlockTextSurface(kind: block.kind) {
                    TextEditor(text: $block.text, selection: $block.selection)
                        .font(block.kind.editorFont)
                        .scrollContentBackground(.hidden)
                        .scrollDisabled(true)
                        .contentMargins(.horizontal, 0, for: .scrollContent)
                        .contentMargins(.vertical, 0, for: .scrollContent)
                        .frame(maxWidth: .infinity, minHeight: minimumEditorHeight, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .focused(focusedField, equals: .block(block.id))
                        .accessibilityLabel(block.kind.accessibilityLabel)
                        .onChange(of: block.selection) { _, _ in
                            selectionChanged()
                        }
                }
            } else if block.isEditable && isReadOnly == false {
                Button(action: focusBlock) {
                    NativeEditorBlockTextSurface(kind: block.kind) {
                        NativeEditorRichBlockPreviewView(
                            block: block,
                            pageID: pageID,
                            spaceID: spaceID,
                            serverURLString: serverURLString
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(.rect)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(block.kind.accessibilityLabel)
            } else {
                NativeEditorRichBlockPreviewView(
                    block: block,
                    tableActions: tableActions,
                    richBlockActions: activeRichBlockActions,
                    pageID: pageID,
                    spaceID: spaceID,
                    serverURLString: serverURLString
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

    private var showsEditableTextEditor: Bool {
        NativeEditorBlockRowPolicy.showsEditableTextEditor(block: block, isReadOnly: isReadOnly)
    }

    private var showsControls: Bool {
        isReadOnly == false && (isShowingControls || isSelected)
    }

    private var hasVisiblePrefix: Bool {
        switch block.kind {
        case .bulletListItem, .orderedListItem, .taskListItem, .unsupported:
            true
        default:
            false
        }
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
}
