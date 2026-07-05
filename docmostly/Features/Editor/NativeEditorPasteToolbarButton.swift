import SwiftUI

struct NativeEditorPasteToolbarButton: View {
    @Bindable var viewModel: NativeRichEditorViewModel

    var body: some View {
        PasteButton(payloadType: String.self) { values in
            viewModel.pasteMarkdown(values.joined(separator: "\n"))
        }
        .labelStyle(.iconOnly)
        .controlSize(.small)
        .buttonBorderShape(.capsule)
        .keyboardShortcut("v", modifiers: [.command, .shift])
        .accessibilityLabel("Paste Markdown")
        .nativeEditorToolbarControlFrame()
    }
}
