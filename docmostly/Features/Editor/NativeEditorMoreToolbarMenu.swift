import SwiftUI

struct NativeEditorMoreToolbarMenu: View {
    @Bindable var viewModel: NativeRichEditorViewModel
    @Binding var isShowingSearchReplace: Bool
    @Binding var isShowingStatusPrompt: Bool
    @Binding var isShowingMathPrompt: Bool
    let showMentionPicker: () -> Void
    let showInlineCommentComposer: () -> Void

    var body: some View {
        Menu("More Formatting", systemImage: "ellipsis") {
            Section("Formatting") {
                Button("Underline", systemImage: "underline") {
                    viewModel.toggleInlineMark(.underline)
                }
                .keyboardShortcut("u", modifiers: .command)

                Button("Strikethrough", systemImage: "strikethrough") {
                    viewModel.toggleInlineMark(.strikethrough)
                }

                Button("Subscript", systemImage: "textformat.subscript") {
                    viewModel.toggleInlineMark(.subscript)
                }

                Button("Superscript", systemImage: "textformat.superscript") {
                    viewModel.toggleInlineMark(.superscript)
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
            }

            Section("Insert") {
                NativeEditorInlineInsertMenu(
                    isShowingStatusPrompt: $isShowingStatusPrompt,
                    isShowingMathPrompt: $isShowingMathPrompt,
                    showMentionPicker: showMentionPicker,
                    showInlineCommentComposer: showInlineCommentComposer
                )
            }

            Section("Alignment") {
                Button("Left", systemImage: "text.alignleft") {
                    viewModel.setActiveAlignment(.left)
                }
                Button("Center", systemImage: "text.aligncenter") {
                    viewModel.setActiveAlignment(.center)
                }
                Button("Right", systemImage: "text.alignright") {
                    viewModel.setActiveAlignment(.right)
                }
            }

            Section("Block") {
                Button("Outdent", systemImage: "decrease.indent") {
                    viewModel.outdentActiveBlock()
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("Indent", systemImage: "increase.indent") {
                    viewModel.indentActiveBlock()
                }
                .keyboardShortcut("]", modifiers: .command)

                Button("Add Block", systemImage: "plus", action: viewModel.appendBlock)
                    .keyboardShortcut(.return, modifiers: .command)
            }

            Section("Find and Copy") {
                Button("Find", systemImage: "magnifyingglass") {
                    isShowingSearchReplace.toggle()
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Copy Markdown", systemImage: "doc.on.clipboard") {
                    viewModel.copyActiveBlockMarkdownToClipboard()
                }
                .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }
        .accessibilityLabel("More Formatting")
        .nativeEditorToolbarControlFrame()
    }
}
