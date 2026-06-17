import SwiftUI

struct NativeEditorBlockCommandToolbarGroup: View {
    @Bindable var viewModel: NativeRichEditorViewModel

    var body: some View {
        ForEach(NativeEditorCommand.primaryCases) { command in
            Button {
                viewModel.applySlashCommand(command)
            } label: {
                Label(command.title, systemImage: command.systemImage)
            }
            .accessibilityLabel(command.title)
        }

        Menu {
            ForEach(NativeEditorCommand.richCases) { command in
                Button {
                    viewModel.applySlashCommand(command)
                } label: {
                    Label(command.title, systemImage: command.systemImage)
                }
            }
        } label: {
            Label("Rich Blocks", systemImage: "square.grid.2x2")
        }
        .accessibilityLabel("Rich Blocks")
    }
}
