import SwiftUI

struct SpaceAddMembersSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SpaceSettingsViewModel
    @State private var workspaceMembers: [DocmostUser] = []
    @State private var groups: [DocmostGroup] = []
    @State private var selectedUserIds: Set<String> = []
    @State private var selectedGroupIds: Set<String> = []
    @State private var role = "reader"
    @State private var searchText = ""
    @State private var isLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Role") {
                    Picker("Role", selection: $role) {
                        ForEach(SettingsRoleOption.spaceRoles) { role in
                            Text(role.label).tag(role.value)
                        }
                    }
                }

                Section("Users") {
                    ForEach(filteredUsers) { member in
                        SpaceAddMemberCandidateRowView(
                            title: member.name,
                            subtitle: member.email,
                            isSelected: selectedUserIds.contains(member.id)
                        ) {
                            toggleUser(member.id)
                        }
                    }
                }

                Section("Groups") {
                    ForEach(filteredGroups) { group in
                        SpaceAddMemberCandidateRowView(
                            title: group.name,
                            subtitle: group.description,
                            isSelected: selectedGroupIds.contains(group.id)
                        ) {
                            toggleGroup(group.id)
                        }
                    }
                }

                if isLoading {
                    ProgressView("Loading members")
                }

                if let errorMessage {
                    SettingsStatusMessageView(message: errorMessage, isError: true)
                }
            }
            .navigationTitle("Add Members")
            .searchable(text: $searchText, prompt: "Search users and groups")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", systemImage: "person.badge.plus", action: addMembers)
                        .disabled(canAdd == false)
                }
            }
            .task {
                await loadCandidates()
            }
        }
    }

    private var canAdd: Bool {
        isSaving == false && (selectedUserIds.isEmpty == false || selectedGroupIds.isEmpty == false)
    }

    private var existingMemberIds: Set<String> {
        Set(viewModel.members.map(\.id))
    }

    private var filteredUsers: [DocmostUser] {
        let users = workspaceMembers.filter { existingMemberIds.contains($0.id) == false }
        return filtered(users: users)
    }

    private var filteredGroups: [DocmostGroup] {
        let availableGroups = groups.filter { existingMemberIds.contains($0.id) == false }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return availableGroups }
        return availableGroups.filter { group in
            group.name.localizedStandardContains(trimmed) ||
            (group.description?.localizedStandardContains(trimmed) ?? false)
        }
    }

    private func filtered(users: [DocmostUser]) -> [DocmostUser] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return users }
        return users.filter { user in
            user.name.localizedStandardContains(trimmed) ||
            (user.email?.localizedStandardContains(trimmed) ?? false)
        }
    }

    private func loadCandidates() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            workspaceMembers = try await appState.loadWorkspaceMembers()
            groups = try await appState.loadGroups()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleUser(_ id: String) {
        if selectedUserIds.contains(id) {
            selectedUserIds.remove(id)
        } else {
            selectedUserIds.insert(id)
        }
    }

    private func toggleGroup(_ id: String) {
        if selectedGroupIds.contains(id) {
            selectedGroupIds.remove(id)
        } else {
            selectedGroupIds.insert(id)
        }
    }

    private func addMembers() {
        Task {
            isSaving = true
            errorMessage = nil
            let success = await viewModel.addMembers(
                role: role,
                userIds: selectedUserIds.sorted(),
                groupIds: selectedGroupIds.sorted(),
                appState: appState
            )
            isSaving = false
            if success {
                dismiss()
            } else {
                errorMessage = viewModel.errorMessage
            }
        }
    }
}
