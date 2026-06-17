import SwiftUI

struct NativeEditorClipboardToolbarGroup: View {
    @Bindable var viewModel: NativeRichEditorViewModel
    @Binding var isShowingSearchReplace: Bool

    var body: some View {
        Button {
            isShowingSearchReplace.toggle()
        } label: {
            Label("Find", systemImage: "magnifyingglass")
        }
        .keyboardShortcut("f", modifiers: .command)

        Button {
            viewModel.copyActiveBlockMarkdownToClipboard()
        } label: {
            Label("Copy Markdown", systemImage: "doc.on.clipboard")
        }
        .keyboardShortcut("c", modifiers: [.command, .shift])

        PasteButton(payloadType: String.self) { values in
            viewModel.pasteMarkdown(values.joined(separator: "\n"))
        }
        .labelStyle(.iconOnly)
        .keyboardShortcut("v", modifiers: [.command, .shift])
    }
}
