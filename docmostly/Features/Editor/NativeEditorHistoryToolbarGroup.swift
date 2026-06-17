import SwiftUI

struct NativeEditorHistoryToolbarGroup: View {
    @Bindable var viewModel: NativeRichEditorViewModel

    var body: some View {
        Button {
            viewModel.undo()
        } label: {
            Label("Undo", systemImage: "arrow.uturn.backward")
        }
        .disabled(viewModel.canUndo == false)
        .keyboardShortcut("z", modifiers: .command)

        Button {
            viewModel.redo()
        } label: {
            Label("Redo", systemImage: "arrow.uturn.forward")
        }
        .disabled(viewModel.canRedo == false)
        .keyboardShortcut("z", modifiers: [.command, .shift])
    }
}
