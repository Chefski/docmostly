import SwiftUI

struct NativeEditorSlashCommandMenu: View {
    @Bindable var viewModel: NativeRichEditorViewModel
    var importAttachment: (NativeEditorAttachmentImportKind) -> Void = { _ in }
    var applyCommand: ((NativeEditorCommand) -> Void)?
    var commandFilter: (NativeEditorCommand) -> Bool = { _ in true }

    var body: some View {
        let commands = viewModel.filteredSlashCommands.filter(commandFilter)

        DocmostlyGlassPanel(cornerRadius: 18, isInteractive: true) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Commands")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 4)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        if commands.isEmpty {
                            Text("No matching commands")
                                .foregroundStyle(.secondary)
                                .padding()
                        } else {
                            ForEach(commands) { command in
                                NativeEditorSlashCommandRow(command: command) {
                                    if let importKind = command.attachmentImportKind {
                                        importAttachment(importKind)
                                    } else if let applyCommand {
                                        applyCommand(command)
                                    } else {
                                        viewModel.applySlashCommand(command)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 320)
            }
            .frame(maxWidth: 380, alignment: .leading)
        }
    }
}

private struct NativeEditorSlashCommandRow: View {
    let command: NativeEditorCommand
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: command.systemImage)
                    .frame(width: 24)
                    .foregroundStyle(DocmostlyTheme.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(command.title)
                    Text(command.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .contentShape(.rect)
            .padding(.horizontal)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }
}
