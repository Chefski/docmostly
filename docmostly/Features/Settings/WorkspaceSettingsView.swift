import SwiftUI

struct WorkspaceSettingsView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: SettingsManagementViewModel

    var body: some View {
        Form {
            if viewModel.isLoading {
                Section {
                    ProgressView("Loading workspace")
                }
            }

            Section("Identity") {
                TextField("Name", text: $viewModel.workspaceDraft.name)
                    .docmostlyTextInputAutocapitalization(.words)
                TextField("Icon", text: $viewModel.workspaceDraft.logo)
                    .docmostlyTextInputAutocapitalization(.never)
                if let workspace = viewModel.workspace {
                    LabeledContent("Members", value: (workspace.memberCount ?? 0).formatted(.number))
                    if let plan = workspace.plan {
                        LabeledContent("Plan", value: plan)
                    }
                }
            }
            .disabled(viewModel.canManageWorkspace == false)

            Section("Security") {
                Toggle("Disable public sharing", isOn: $viewModel.workspaceDraft.disablePublicSharing)
                Toggle("Restrict API keys to admins", isOn: $viewModel.workspaceDraft.restrictApiToAdmins)
                Stepper(
                    "Trash retention: \(viewModel.workspaceDraft.trashRetentionDays.formatted(.number)) days",
                    value: $viewModel.workspaceDraft.trashRetentionDays,
                    in: 1...365
                )
            }
            .disabled(viewModel.canManageWorkspace == false)

            Section("Workspace Features") {
                Toggle("Member templates", isOn: $viewModel.workspaceDraft.allowMemberTemplates)
                Toggle("AI search", isOn: $viewModel.workspaceDraft.aiSearch)
                Toggle("Generative AI", isOn: $viewModel.workspaceDraft.generativeAi)
                Toggle("MCP", isOn: $viewModel.workspaceDraft.mcpEnabled)
            }
            .disabled(viewModel.canManageWorkspace == false)

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
        .navigationTitle("Workspace")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", systemImage: "checkmark", action: save)
                    .disabled(canSave == false)
            }
        }
        .task {
            await viewModel.loadWorkspace(appState: appState)
        }
    }

    private var canSave: Bool {
        guard let workspace = viewModel.workspace else { return false }
        return viewModel.canManageWorkspace &&
        viewModel.workspaceDraft.validationMessage == nil &&
        viewModel.workspaceDraft.hasChanges(comparedTo: workspace) &&
        viewModel.isSaving == false
    }

    private func save() {
        Task {
            _ = await viewModel.saveWorkspace(appState: appState)
        }
    }
}
