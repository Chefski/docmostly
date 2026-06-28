import SwiftUI

struct SpaceAddMembersSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: SpaceSettingsViewModel
    @State private var userCandidates: [SpaceAddMemberCandidate] = []
    @State private var groupCandidates: [SpaceAddMemberCandidate] = []
    @State private var filteredUserCandidates: [SpaceAddMemberCandidate] = []
    @State private var filteredGroupCandidates: [SpaceAddMemberCandidate] = []
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

                SpaceAddMembersUserSection(
                    users: filteredUserCandidates,
                    selectedUserIds: selectedUserIds,
                    toggle: toggleUser
                )
                .equatable()

                SpaceAddMembersGroupSection(
                    groups: filteredGroupCandidates,
                    selectedGroupIds: selectedGroupIds,
                    toggle: toggleGroup
                )
                .equatable()

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
            .onChange(of: searchText) { _, _ in
                refreshFilteredCandidates()
            }
            .onChange(of: viewModel.members) { _, _ in
                refreshFilteredCandidates()
            }
        }
    }

    private var canAdd: Bool {
        isSaving == false && (selectedUserIds.isEmpty == false || selectedGroupIds.isEmpty == false)
    }

    private func refreshFilteredCandidates() {
        let existingMemberIds = Set(viewModel.members.map(\.id))
        let availableUsers = userCandidates.filter { existingMemberIds.contains($0.id) == false }
        let availableGroups = groupCandidates.filter { existingMemberIds.contains($0.id) == false }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmed.isEmpty == false else {
            updateFilteredCandidates(users: availableUsers, groups: availableGroups)
            return
        }

        updateFilteredCandidates(
            users: availableUsers.filter { $0.matches(trimmed) },
            groups: availableGroups.filter { $0.matches(trimmed) }
        )
    }

    private func updateFilteredCandidates(
        users: [SpaceAddMemberCandidate],
        groups: [SpaceAddMemberCandidate]
    ) {
        if filteredUserCandidates != users {
            filteredUserCandidates = users
        }
        if filteredGroupCandidates != groups {
            filteredGroupCandidates = groups
        }
    }

    private func loadCandidates() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let workspaceMembers = try await appState.loadWorkspaceMembers()
            let groups = try await appState.loadGroups()
            userCandidates = workspaceMembers.map(SpaceAddMemberCandidate.init(user:))
            groupCandidates = groups.map(SpaceAddMemberCandidate.init(group:))
            refreshFilteredCandidates()
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

private struct SpaceAddMemberCandidate: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String?

    init(id: String, title: String, subtitle: String?) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
    }

    init(user: DocmostUser) {
        self.init(id: user.id, title: user.name, subtitle: user.email)
    }

    init(group: DocmostGroup) {
        self.init(id: group.id, title: group.name, subtitle: group.description)
    }

    func matches(_ query: String) -> Bool {
        title.localizedStandardContains(query) ||
            (subtitle?.localizedStandardContains(query) ?? false)
    }
}

private struct SpaceAddMembersUserSection: View, Equatable {
    let users: [SpaceAddMemberCandidate]
    let selectedUserIds: Set<String>
    let toggle: (String) -> Void

    var body: some View {
        Section("Users") {
            ForEach(users) { member in
                SpaceAddMemberCandidateRowView(
                    title: member.title,
                    subtitle: member.subtitle,
                    isSelected: selectedUserIds.contains(member.id)
                ) {
                    toggle(member.id)
                }
                .equatable()
            }
        }
    }

    static func == (lhs: SpaceAddMembersUserSection, rhs: SpaceAddMembersUserSection) -> Bool {
        lhs.users == rhs.users &&
            lhs.selectedUserIds == rhs.selectedUserIds
    }
}

private struct SpaceAddMembersGroupSection: View, Equatable {
    let groups: [SpaceAddMemberCandidate]
    let selectedGroupIds: Set<String>
    let toggle: (String) -> Void

    var body: some View {
        Section("Groups") {
            ForEach(groups) { group in
                SpaceAddMemberCandidateRowView(
                    title: group.title,
                    subtitle: group.subtitle,
                    isSelected: selectedGroupIds.contains(group.id)
                ) {
                    toggle(group.id)
                }
                .equatable()
            }
        }
    }

    static func == (lhs: SpaceAddMembersGroupSection, rhs: SpaceAddMembersGroupSection) -> Bool {
        lhs.groups == rhs.groups &&
            lhs.selectedGroupIds == rhs.selectedGroupIds
    }
}
