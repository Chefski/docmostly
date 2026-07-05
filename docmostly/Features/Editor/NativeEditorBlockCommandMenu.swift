import SwiftUI

struct NativeEditorBlockCommandMenu: View {
    @Bindable var viewModel: NativeRichEditorViewModel
    var applyCommand: ((NativeEditorCommand) -> Void)?

    var body: some View {
        Menu {
            Section("Basic Blocks") {
                ForEach(NativeEditorCommand.primaryCases) { command in
                    Button {
                        apply(command)
                    } label: {
                        Label(command.title, systemImage: command.systemImage)
                    }
                }
            }

            Section("Rich Blocks") {
                ForEach(NativeEditorCommand.richCases) { command in
                    Button {
                        apply(command)
                    } label: {
                        Label(command.title, systemImage: command.systemImage)
                    }
                }
            }
        } label: {
            Label("Blocks", systemImage: "square.grid.2x2")
        }
        .accessibilityLabel("Blocks")
        .nativeEditorToolbarControlFrame()
    }

    private func apply(_ command: NativeEditorCommand) {
        if let applyCommand {
            applyCommand(command)
        } else {
            viewModel.applySlashCommand(command)
        }
    }
}
