import SwiftUI

struct NativeEditorBlockRow: View {
    @Binding var block: NativeEditorBlock
    let focusedField: FocusState<NativeEditorFocus?>.Binding
    let isSelected: Bool
    let isShowingControls: Bool
    let select: () -> Void
    let showControls: () -> Void
    let insertBelow: () -> Void
    let delete: () -> Void
    let moveBefore: (UUID) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
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
                        NativeEditorBlockPrefix(block: $block)
                            .frame(width: 24, alignment: .center)
                    }
                }
            } else if hasVisiblePrefix {
                NativeEditorBlockPrefix(block: $block)
                    .frame(width: 24, alignment: .center)
            }

            if block.isEditable {
                TextEditor(text: $block.text, selection: $block.selection)
                    .font(block.kind.editorFont)
                    .scrollContentBackground(.hidden)
                    .frame(maxWidth: .infinity, minHeight: minimumEditorHeight, alignment: .leading)
                    .focused(focusedField, equals: .block(block.id))
                    .accessibilityLabel(block.kind.accessibilityLabel)
            } else {
                NativeEditorUnsupportedBlockView(block: block)
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
        .padding(.vertical, 2)
        .background {
            (isSelected ? DocmostlyTheme.primaryTint : Color.clear)
                .clipShape(.rect(cornerRadius: 8))
                .contentShape(.rect)
                .onLongPressGesture(perform: showControls)
        }
        .dropDestination(for: String.self) { blockIDs, _ in
            guard
                let rawBlockID = blockIDs.first,
                let movedBlockID = UUID(uuidString: rawBlockID)
            else {
                return false
            }

            moveBefore(movedBlockID)
            return true
        }
    }

    private var minimumEditorHeight: CGFloat {
        switch block.kind {
        case .heading:
            58
        case .codeBlock:
            88
        default:
            46
        }
    }

    private var showsControls: Bool {
        isShowingControls || isSelected
    }

    private var hasVisiblePrefix: Bool {
        switch block.kind {
        case .bulletListItem, .orderedListItem, .taskListItem, .blockquote, .codeBlock, .unsupported:
            true
        default:
            false
        }
    }
}
