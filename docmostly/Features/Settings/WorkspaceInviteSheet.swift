import SwiftUI

struct WorkspaceInviteSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SettingsManagementViewModel
    @State private var draft = WorkspaceInvitationDraft()
    @State private var isSending = false
    @State private var hasEdited = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Invite") {
                    TextField("Email addresses", text: $draft.emailsText, axis: .vertical)
                        .lineLimit(2...)
                        .docmostlyTextInputAutocapitalization(.never)
                        .onChange(of: draft.emailsText) {
                            hasEdited = true
                        }

                    Picker("Role", selection: $draft.role) {
                        Text("Member").tag("member")
                        Text("Admin").tag("admin")
                    }
                }

                if viewModel.groups.isEmpty == false {
                    Section("Groups") {
                        ForEach(viewModel.groups) { group in
                            Button {
                                draft.toggleGroup(id: group.id)
                            } label: {
                                HStack {
                                    Text(group.name)
                                    Spacer()
                                    if draft.selectedGroupIds.contains(group.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(DocmostlyTheme.primary)
                                    }
                                }
                            }
                        }
                    }
                }

                if let validationMessage = draft.validationMessage, hasEdited {
                    Section {
                        SettingsStatusMessageView(message: validationMessage, isError: true)
                    }
                } else if let message = viewModel.errorMessage {
                    Section {
                        SettingsStatusMessageView(message: message, isError: true)
                    }
                }
            }
            .navigationTitle("Invite People")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send", systemImage: "paperplane", action: send)
                        .disabled(draft.canSend == false || isSending)
                }
            }
            .task {
                await viewModel.loadGroups(appState: appState)
            }
        }
    }

    private func send() {
        Task {
            isSending = true
            let sent = await viewModel.createInvitation(draft, appState: appState)
            isSending = false
            if sent {
                dismiss()
            } else {
                hasEdited = true
            }
        }
    }
}
