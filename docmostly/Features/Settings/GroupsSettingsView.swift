import SwiftUI

struct GroupsSettingsView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: SettingsManagementViewModel
    @State private var searchText = ""
    @State private var isShowingCreateGroup = false
    @State private var groupToDelete: DocmostGroup?
    @State private var isConfirmingDelete = false

    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView("Loading groups")
            }

            ForEach(viewModel.filteredGroups(query: searchText)) { group in
                GroupSettingsRowView(group: group, canManage: viewModel.canManageWorkspace, delete: confirmDelete)
            }

            if viewModel.groups.isEmpty, viewModel.isLoading == false {
                ContentUnavailableView("No Groups", systemImage: "person.3")
            }

            if let message = viewModel.errorMessage {
                SettingsStatusMessageView(message: message, isError: true)
            } else if let message = viewModel.statusMessage {
                SettingsStatusMessageView(message: message, isError: false)
            }
        }
        .navigationTitle("Groups")
        .searchable(text: $searchText, prompt: "Search groups")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("New Group", systemImage: "plus", action: showCreateGroup)
                    .disabled(viewModel.canManageWorkspace == false)
            }
        }
        .sheet(isPresented: $isShowingCreateGroup) {
            GroupCreateSheet(viewModel: viewModel)
        }
        .task {
            await viewModel.loadGroups(appState: appState)
        }
        .confirmationDialog("Delete Group", isPresented: $isConfirmingDelete) {
            Button("Delete", role: .destructive, action: deleteConfirmedGroup)
            Button("Cancel", role: .cancel, action: cancelDelete)
        }
    }

    private func showCreateGroup() {
        isShowingCreateGroup = true
    }

    private func confirmDelete(_ group: DocmostGroup) {
        groupToDelete = group
        isConfirmingDelete = true
    }

    private func deleteConfirmedGroup() {
        guard let groupToDelete else { return }
        Task {
            await viewModel.deleteGroup(groupToDelete, appState: appState)
            self.groupToDelete = nil
        }
    }

    private func cancelDelete() {
        groupToDelete = nil
    }
}
