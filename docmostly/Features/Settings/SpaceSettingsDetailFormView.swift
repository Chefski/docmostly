import SwiftUI

struct SpaceSettingsDetailFormView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SpaceSettingsViewModel
    let canManage: Bool
    @State private var memberSearchText = ""
    @State private var isConfirmingDelete = false
    @State private var isShowingAddMembers = false

    var body: some View {
        Form {
            Section("Details") {
                TextField("Name", text: $viewModel.draft.name)
                    .textInputAutocapitalization(.words)
                    .onChange(of: viewModel.draft.name) { _, newValue in
                        viewModel.draft.setName(newValue)
                    }
                TextField("Slug", text: $viewModel.draft.slug)
                    .textInputAutocapitalization(.never)
                TextField("Description", text: $viewModel.draft.description, axis: .vertical)
                    .lineLimit(2...)
            }
            .disabled(canManage == false)

            Section("Security") {
                Toggle("Disable public sharing", isOn: $viewModel.draft.disablePublicSharing)
                Toggle("Allow viewer comments", isOn: $viewModel.draft.allowViewerComments)
            }
            .disabled(canManage == false)

            Section("Notifications") {
                Toggle("Watch this space", isOn: watchingSpaceBinding)
                    .disabled(viewModel.isLoadingWatchStatus || viewModel.isTogglingWatch)

                if viewModel.isLoadingWatchStatus || viewModel.isTogglingWatch {
                    ProgressView(viewModel.isLoadingWatchStatus ? "Loading watch status" : "Updating watch status")
                }
            }

            Section("Members") {
                if canManage {
                    Button("Add Members", systemImage: "person.badge.plus", action: showAddMembers)
                }

                TextField("Search members", text: $memberSearchText)
                    .textInputAutocapitalization(.never)

                if viewModel.isLoading {
                    ProgressView("Loading members")
                }

                ForEach(viewModel.filteredMembers(query: memberSearchText)) { member in
                    SpaceMemberRowView(
                        member: member,
                        canManage: canManage,
                        changeRole: changeRole,
                        remove: removeMember
                    )
                }

                if viewModel.members.isEmpty, viewModel.isLoading == false {
                    ContentUnavailableView("No Members", systemImage: "person.2")
                }
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

            if canManage {
                Section {
                    Button("Delete Space", systemImage: "trash", role: .destructive, action: confirmDelete)
                }
            }
        }
        .navigationTitle(viewModel.space.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save", systemImage: "checkmark", action: save)
                    .disabled(viewModel.canSave == false || viewModel.isSaving || canManage == false)
            }
        }
        .task(id: viewModel.space.id) {
            await viewModel.loadMembers(appState: appState)
            await viewModel.loadWatchStatus(appState: appState)
        }
        .confirmationDialog("Delete Space", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive, action: deleteSpace)
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $isShowingAddMembers) {
            SpaceAddMembersSheet(viewModel: viewModel)
        }
    }

    private func save() {
        Task {
            _ = await viewModel.save(appState: appState)
        }
    }

    private var watchingSpaceBinding: Binding<Bool> {
        Binding {
            viewModel.isWatchingSpace
        } set: { shouldWatch in
            Task {
                await viewModel.setWatchingSpace(shouldWatch, appState: appState)
            }
        }
    }

    private func changeRole(_ member: DocmostSpaceMember, _ role: String) {
        Task {
            await viewModel.changeMemberRole(member, role: role, appState: appState)
        }
    }

    private func removeMember(_ member: DocmostSpaceMember) {
        Task {
            await viewModel.removeMember(member, appState: appState)
        }
    }

    private func showAddMembers() {
        isShowingAddMembers = true
    }

    private func confirmDelete() {
        isConfirmingDelete = true
    }

    private func deleteSpace() {
        Task {
            let deleted = await viewModel.delete(appState: appState)
            if deleted {
                dismiss()
            }
        }
    }
}
