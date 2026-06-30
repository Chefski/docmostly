import SwiftUI

struct NativeEditorSlashCommandMenu: View {
    @Bindable var viewModel: NativeRichEditorViewModel
    var importAttachment: (NativeEditorAttachmentImportKind) -> Void = { _ in }
    var applyCommand: ((NativeEditorCommand) -> Void)?

    var body: some View {
        let commands = viewModel.filteredSlashCommands

        VStack(alignment: .leading, spacing: 0) {
            Text("Commands")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 4)

            if commands.isEmpty {
                Text("No matching commands")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                ForEach(commands) { command in
                    Button {
                        if let importKind = command.attachmentImportKind {
                            importAttachment(importKind)
                        } else if let applyCommand {
                            applyCommand(command)
                        } else {
                            viewModel.applySlashCommand(command)
                        }
                    } label: {
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
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: 380, alignment: .leading)
        .background(.regularMaterial, in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary)
        }
    }
}
