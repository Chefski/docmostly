import SwiftUI

struct NativeEditorBlockCommandToolbarGroup: View {
    @Bindable var viewModel: NativeRichEditorViewModel

    var body: some View {
        ForEach(NativeEditorCommand.allCases) { command in
            Button {
                viewModel.applySlashCommand(command)
            } label: {
                Label(command.title, systemImage: command.systemImage)
            }
            .accessibilityLabel(command.title)
        }
    }
}
