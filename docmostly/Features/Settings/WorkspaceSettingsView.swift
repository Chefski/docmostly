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
                    .disabled(viewModel.hasWorkspaceFeature(.sharingControls) == false)
                Toggle("Restrict API keys to admins", isOn: $viewModel.workspaceDraft.restrictApiToAdmins)
                    .disabled(viewModel.hasWorkspaceFeature(.apiKeys) == false)
                Stepper(
                    "Trash retention: \(viewModel.workspaceDraft.trashRetentionDays.formatted(.number)) days",
                    value: $viewModel.workspaceDraft.trashRetentionDays,
                    in: 1...365
                )
                .disabled(viewModel.hasWorkspaceFeature(.retention) == false)
            }
            .disabled(viewModel.canManageWorkspace == false)

            Section {
                Toggle("Member templates", isOn: $viewModel.workspaceDraft.allowMemberTemplates)
                    .disabled(viewModel.hasWorkspaceFeature(.templates) == false)
                Toggle("AI search", isOn: $viewModel.workspaceDraft.aiSearch)
                    .disabled(viewModel.hasWorkspaceFeature(.artificialIntelligence) == false)
                Toggle("Generative AI", isOn: $viewModel.workspaceDraft.generativeAi)
                    .disabled(viewModel.hasWorkspaceFeature(.artificialIntelligence) == false)
                Toggle("MCP", isOn: $viewModel.workspaceDraft.mcpEnabled)
                    .disabled(viewModel.hasWorkspaceFeature(.mcp) == false)
            } header: {
                Text("Workspace Features")
            } footer: {
                if viewModel.isLoading == false {
                    if viewModel.workspaceEntitlements == nil {
                        Text("Feature availability could not be verified. Licensed controls are unavailable.")
                    } else if viewModel.hasUnavailableLicensedSettings {
                        Text("Unavailable settings require a compatible workspace plan or license.")
                    }
                }
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
        guard viewModel.workspace != nil else { return false }
        return viewModel.canManageWorkspace &&
        viewModel.workspaceDraft.validationMessage == nil &&
        viewModel.hasWorkspaceChanges &&
        viewModel.isSaving == false
    }

    private func save() {
        Task {
            _ = await viewModel.saveWorkspace(appState: appState)
        }
    }
}
