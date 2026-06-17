import SwiftUI

struct NativeEditorFormattingToolbarGroup: View {
    @Bindable var viewModel: NativeRichEditorViewModel
    @Binding var isShowingStatusPrompt: Bool
    @Binding var isShowingMentionPrompt: Bool
    @Binding var isShowingCommentPrompt: Bool
    @Binding var isShowingMathPrompt: Bool

    var body: some View {
        Button {
            viewModel.toggleInlineMark(.bold)
        } label: {
            Label("Bold", systemImage: "bold")
        }
        .keyboardShortcut("b", modifiers: .command)

        Button {
            viewModel.toggleInlineMark(.italic)
        } label: {
            Label("Italic", systemImage: "italic")
        }
        .keyboardShortcut("i", modifiers: .command)

        Button {
            viewModel.toggleInlineMark(.underline)
        } label: {
            Label("Underline", systemImage: "underline")
        }
        .keyboardShortcut("u", modifiers: .command)

        Button {
            viewModel.toggleInlineMark(.strikethrough)
        } label: {
            Label("Strikethrough", systemImage: "strikethrough")
        }

        Button {
            viewModel.toggleInlineMark(.code)
        } label: {
            Label("Inline Code", systemImage: "chevron.left.forwardslash.chevron.right")
        }
        .keyboardShortcut("e", modifiers: .command)

        Button {
            viewModel.toggleInlineMark(.subscript)
        } label: {
            Label("Subscript", systemImage: "textformat.subscript")
        }

        Button {
            viewModel.toggleInlineMark(.superscript)
        } label: {
            Label("Superscript", systemImage: "textformat.superscript")
        }

        NativeEditorColorMenu(
            title: "Highlight",
            systemImage: "highlighter",
            options: NativeEditorColorOption.highlights
        ) { option in
            viewModel.applyHighlight(color: option.hex, colorName: option.colorName)
        }

        NativeEditorColorMenu(
            title: "Text Color",
            systemImage: "paintpalette",
            options: NativeEditorColorOption.textColors
        ) { option in
            viewModel.applyTextColor(option.hex)
        }

        NativeEditorInlineInsertMenu(
            isShowingStatusPrompt: $isShowingStatusPrompt,
            isShowingMentionPrompt: $isShowingMentionPrompt,
            isShowingCommentPrompt: $isShowingCommentPrompt,
            isShowingMathPrompt: $isShowingMathPrompt
        )
    }
}
