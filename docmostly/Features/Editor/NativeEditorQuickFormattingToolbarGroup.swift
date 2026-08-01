import SwiftUI

struct NativeEditorQuickFormattingToolbarGroup: View {
    @Bindable var viewModel: NativeRichEditorViewModel
    @Binding var isShowingLinkPrompt: Bool

    var body: some View {
        Button {
            viewModel.toggleInlineMark(.bold)
        } label: {
            Label("Bold", systemImage: "bold")
        }
        .keyboardShortcut("b", modifiers: .command)
        .nativeEditorToolbarControlFrame()
        .background(
            viewModel.isInlineMarkActive(.bold) ? DocmostlyTheme.primaryTint : .clear,
            in: .rect(cornerRadius: 8)
        )
        .accessibilityAddTraits(viewModel.isInlineMarkActive(.bold) ? .isSelected : [])

        Button {
            viewModel.toggleInlineMark(.italic)
        } label: {
            Label("Italic", systemImage: "italic")
        }
        .keyboardShortcut("i", modifiers: .command)
        .nativeEditorToolbarControlFrame()
        .background(
            viewModel.isInlineMarkActive(.italic) ? DocmostlyTheme.primaryTint : .clear,
            in: .rect(cornerRadius: 8)
        )
        .accessibilityAddTraits(viewModel.isInlineMarkActive(.italic) ? .isSelected : [])

        Button {
            viewModel.toggleInlineMark(.code)
        } label: {
            Label("Inline Code", systemImage: "chevron.left.forwardslash.chevron.right")
        }
        .keyboardShortcut("e", modifiers: .command)
        .nativeEditorToolbarControlFrame()
        .background(
            viewModel.isInlineMarkActive(.code) ? DocmostlyTheme.primaryTint : .clear,
            in: .rect(cornerRadius: 8)
        )
        .accessibilityAddTraits(viewModel.isInlineMarkActive(.code) ? .isSelected : [])

        Button {
            isShowingLinkPrompt = true
        } label: {
            Label("Link", systemImage: "link")
        }
        .keyboardShortcut("k", modifiers: .command)
        .nativeEditorToolbarControlFrame()
    }
}
