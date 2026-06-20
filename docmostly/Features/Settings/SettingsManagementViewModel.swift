import Foundation
import Observation

@MainActor
@Observable
final class SettingsManagementViewModel {
    var accountDraft = AccountSettingsDraft()
    var workspaceDraft = WorkspaceSettingsDraft()
    var workspace: DocmostWorkspace?
    var workspaceMembers: [DocmostUser] = []
    var workspaceInvitations: [DocmostWorkspaceInvitation] = []
    var groups: [DocmostGroup] = []
    var isLoading = false
    var isSaving = false
    var errorMessage: String?
    var statusMessage: String?

    private var currentUserRole: String?

    var canManageWorkspace: Bool {
        currentUserRole == "owner" || currentUserRole == "admin"
    }

    var currentUserIsOwner: Bool {
        currentUserRole == "owner"
    }

    func seed(from appState: AppState) {
        guard let currentUser = appState.currentUser else { return }
        currentUserRole = currentUser.user.role
        accountDraft.reset(to: currentUser.user)
        workspace = workspace ?? currentUser.workspace
        workspaceDraft = WorkspaceSettingsDraft(workspace: workspace ?? currentUser.workspace)
    }

    func loadWorkspace(appState: AppState) async {
        await load {
            let workspace = try await appState.loadWorkspaceInfo()
            self.workspace = workspace
            workspaceDraft = WorkspaceSettingsDraft(workspace: workspace)
        }
    }

    func saveAccount(appState: AppState) async -> Bool {
        if let validationMessage = accountDraft.validationMessage {
            errorMessage = validationMessage
            return false
        }

        let update = accountDraft.update()
        guard update.hasChanges else { return true }

        return await save(successMessage: "Account updated.") {
            let user = try await appState.updateUser(update)
            accountDraft.reset(to: user)
        }
    }

    func saveWorkspace(appState: AppState) async -> Bool {
        guard let workspace else {
            errorMessage = "Workspace settings are not loaded."
            return false
        }
        if let validationMessage = workspaceDraft.validationMessage {
            errorMessage = validationMessage
            return false
        }

        let update = workspaceDraft.update(comparedTo: workspace)
        guard update.hasChanges else { return true }

        return await save(successMessage: "Workspace updated.") {
            let updated = try await appState.updateWorkspace(update)
            self.workspace = updated
            workspaceDraft = WorkspaceSettingsDraft(workspace: updated)
        }
    }

    func loadWorkspaceMembers(appState: AppState) async {
        await load {
            workspaceMembers = try await appState.loadWorkspaceMembers()
        }
    }

    func loadWorkspaceInvitations(appState: AppState) async {
        await load {
            workspaceInvitations = try await appState.loadWorkspaceInvitations()
        }
    }

    func createInvitation(_ draft: WorkspaceInvitationDraft, appState: AppState) async -> Bool {
        if let validationMessage = draft.validationMessage {
            errorMessage = validationMessage
            return false
        }

        return await save(successMessage: "Invitation sent.") {
            try await appState.createWorkspaceInvitation(
                emails: draft.emails,
                role: draft.role,
                groupIds: draft.groupIds
            )
            workspaceInvitations = try await appState.loadWorkspaceInvitations()
        }
    }

    func resendInvitation(_ invitation: DocmostWorkspaceInvitation, appState: AppState) async {
        _ = await save(successMessage: "Invitation resent.") {
            try await appState.resendWorkspaceInvitation(invitationId: invitation.id)
        }
    }

    func revokeInvitation(_ invitation: DocmostWorkspaceInvitation, appState: AppState) async {
        _ = await save(successMessage: "Invitation revoked.") {
            try await appState.revokeWorkspaceInvitation(invitationId: invitation.id)
            workspaceInvitations.removeAll { $0.id == invitation.id }
        }
    }

    func changeWorkspaceMemberRole(_ member: DocmostUser, role: String, appState: AppState) async {
        guard role != member.role else { return }
        _ = await save(successMessage: "Member role updated.") {
            try await appState.changeWorkspaceMemberRole(userId: member.id, role: role)
            workspaceMembers = try await appState.loadWorkspaceMembers()
        }
    }

    func activateWorkspaceMember(_ member: DocmostUser, appState: AppState) async {
        _ = await save(successMessage: "Member activated.") {
            try await appState.activateWorkspaceMember(userId: member.id)
            workspaceMembers = try await appState.loadWorkspaceMembers()
        }
    }

    func deactivateWorkspaceMember(_ member: DocmostUser, appState: AppState) async {
        _ = await save(successMessage: "Member deactivated.") {
            try await appState.deactivateWorkspaceMember(userId: member.id)
            workspaceMembers = try await appState.loadWorkspaceMembers()
        }
    }

    func deleteWorkspaceMember(_ member: DocmostUser, appState: AppState) async {
        _ = await save(successMessage: "Member removed.") {
            try await appState.deleteWorkspaceMember(userId: member.id)
            workspaceMembers.removeAll { $0.id == member.id }
        }
    }

    func loadGroups(appState: AppState) async {
        await load {
            groups = try await appState.loadGroups()
        }
    }

    func createGroup(name: String, description: String?, appState: AppState) async -> Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedName.isEmpty == false else {
            errorMessage = "Group name is required."
            return false
        }

        return await save(successMessage: "Group created.") {
            let group = try await appState.createGroup(name: trimmedName, description: description)
            groups.append(group)
            groups.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    func deleteGroup(_ group: DocmostGroup, appState: AppState) async {
        _ = await save(successMessage: "Group deleted.") {
            try await appState.deleteGroup(groupId: group.id)
            groups.removeAll { $0.id == group.id }
        }
    }

    func filteredMembers(query: String) -> [DocmostUser] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return workspaceMembers }
        return workspaceMembers.filter { member in
            member.name.localizedStandardContains(trimmed) ||
            (member.email?.localizedStandardContains(trimmed) ?? false)
        }
    }

    func filteredGroups(query: String) -> [DocmostGroup] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return groups }
        return groups.filter { group in
            group.name.localizedStandardContains(trimmed) ||
            (group.description?.localizedStandardContains(trimmed) ?? false)
        }
    }

    func clearMessages() {
        errorMessage = nil
        statusMessage = nil
    }

    private func load(_ operation: () async throws -> Void) async {
        isLoading = true
        clearMessages()
        defer { isLoading = false }

        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(successMessage: String, _ operation: () async throws -> Void) async -> Bool {
        isSaving = true
        clearMessages()
        defer { isSaving = false }

        do {
            try await operation()
            statusMessage = successMessage
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
