import SwiftUI

struct AccountSettingsView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: SettingsManagementViewModel

    var body: some View {
        Form {
            Section("Profile") {
                TextField("Name", text: $viewModel.accountDraft.name)
                    .docmostlyTextInputAutocapitalization(.words)
                LabeledContent(
                    "Email",
                    value: viewModel.accountDraft.email.isEmpty ? "Unavailable" : viewModel.accountDraft.email
                )
            }

            Section("Editor") {
                Toggle("Full page width", isOn: $viewModel.accountDraft.fullPageWidth)
                Toggle("Editor toolbar", isOn: $viewModel.accountDraft.editorToolbar)
                Picker("Default mode", selection: $viewModel.accountDraft.pageEditMode) {
                    Text("Edit").tag("edit")
                    Text("Read").tag("read")
                }
            }

            Section("Notifications") {
                Toggle("Page updates", isOn: $viewModel.accountDraft.notificationPageUpdates)
                Toggle("Page mentions", isOn: $viewModel.accountDraft.notificationPageUserMention)
                Toggle("Comment mentions", isOn: $viewModel.accountDraft.notificationCommentUserMention)
                Toggle("New comments", isOn: $viewModel.accountDraft.notificationCommentCreated)
                Toggle("Resolved comments", isOn: $viewModel.accountDraft.notificationCommentResolved)
            }

            if let message = viewModel.errorMessage {
                Section {
                    SettingsStatusMessageView(message: message, isError: true)
                }
            } else if let message = viewModel.statusMessage {
                Section {
                    SettingsStatusMessageView(message: message, isError: false)
                }
            }
        }
        .navigationTitle("Account")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", systemImage: "checkmark", action: save)
                    .disabled(viewModel.accountDraft.canSave == false || viewModel.isSaving)
            }
        }
        .task {
            viewModel.seed(from: appState)
        }
    }

    private func save() {
        Task {
            _ = await viewModel.saveAccount(appState: appState)
        }
    }
}
