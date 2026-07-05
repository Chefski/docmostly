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

        Button {
            viewModel.toggleInlineMark(.italic)
        } label: {
            Label("Italic", systemImage: "italic")
        }
        .keyboardShortcut("i", modifiers: .command)
        .nativeEditorToolbarControlFrame()

        Button {
            viewModel.toggleInlineMark(.code)
        } label: {
            Label("Inline Code", systemImage: "chevron.left.forwardslash.chevron.right")
        }
        .keyboardShortcut("e", modifiers: .command)
        .nativeEditorToolbarControlFrame()

        Button {
            isShowingLinkPrompt = true
        } label: {
            Label("Link", systemImage: "link")
        }
        .keyboardShortcut("k", modifiers: .command)
        .nativeEditorToolbarControlFrame()
    }
}
