import SwiftUI

struct NativeEditorBlockActionsToolbarGroup: View {
    @Bindable var viewModel: NativeRichEditorViewModel
    let dismissKeyboard: () -> Void

    var body: some View {
        Button {
            viewModel.outdentActiveBlock()
        } label: {
            Label("Outdent", systemImage: "decrease.indent")
        }
        .keyboardShortcut("[", modifiers: .command)

        Button {
            viewModel.indentActiveBlock()
        } label: {
            Label("Indent", systemImage: "increase.indent")
        }
        .keyboardShortcut("]", modifiers: .command)

        Button(action: viewModel.appendBlock) {
            Label("Add Block", systemImage: "plus")
        }
        .keyboardShortcut(.return, modifiers: .command)

        Button(action: dismissKeyboard) {
            Label("Dismiss Keyboard", systemImage: "keyboard.chevron.compact.down")
        }
    }
}
