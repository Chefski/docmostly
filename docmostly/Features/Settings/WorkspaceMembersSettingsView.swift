import SwiftUI

struct WorkspaceMembersSettingsView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: SettingsManagementViewModel
    @State private var searchText = ""
    @State private var memberToRemove: DocmostUser?
    @State private var invitationToRevoke: DocmostWorkspaceInvitation?
    @State private var isConfirmingRemoval = false
    @State private var isConfirmingRevoke = false
    @State private var isShowingInviteSheet = false

    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView("Loading members")
            }

            Section("Members") {
                ForEach(viewModel.filteredMembers(query: searchText)) { member in
                    WorkspaceMemberRowView(
                        member: member,
                        canManage: viewModel.canManageWorkspace,
                        roles: SettingsRoleOption.assignableWorkspaceRoles(isOwner: viewModel.currentUserIsOwner),
                        changeRole: changeRole,
                        activate: activate,
                        deactivate: deactivate,
                        remove: confirmRemoval
                    )
                }

                if viewModel.workspaceMembers.isEmpty, viewModel.isLoading == false {
                    ContentUnavailableView("No Members", systemImage: "person.2")
                }
            }

            Section("Pending Invitations") {
                ForEach(viewModel.workspaceInvitations) { invitation in
                    WorkspaceInvitationRowView(
                        invitation: invitation,
                        canManage: viewModel.canManageWorkspace,
                        resend: resendInvitation,
                        revoke: confirmRevoke
                    )
                }

                if viewModel.workspaceInvitations.isEmpty, viewModel.isLoading == false {
                    ContentUnavailableView("No Pending Invitations", systemImage: "envelope")
                }
            }

            if let message = viewModel.errorMessage {
                SettingsStatusMessageView(message: message, isError: true)
            } else if let message = viewModel.statusMessage {
                SettingsStatusMessageView(message: message, isError: false)
            }
        }
        .navigationTitle("Members")
        .searchable(text: $searchText, prompt: "Search members")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("Member Actions", systemImage: "ellipsis.circle") {
                    Button("Invite People", systemImage: "envelope.badge") {
                        showInviteSheet()
                    }
                    .disabled(viewModel.canManageWorkspace == false)

                    Button("Refresh", systemImage: "arrow.clockwise", action: refresh)
                        .disabled(viewModel.isLoading)
                }
            }
        }
        .task {
            await loadMembersAndInvitations()
        }
        .sheet(isPresented: $isShowingInviteSheet) {
            WorkspaceInviteSheet(viewModel: viewModel)
        }
        .confirmationDialog("Remove Member", isPresented: $isConfirmingRemoval) {
            Button("Remove", role: .destructive, action: removeConfirmedMember)
            Button("Cancel", role: .cancel, action: cancelRemoval)
        }
        .confirmationDialog("Revoke Invitation", isPresented: $isConfirmingRevoke) {
            Button("Revoke", role: .destructive, action: revokeConfirmedInvitation)
            Button("Cancel", role: .cancel, action: cancelRevoke)
        }
    }

    private func refresh() {
        Task {
            await loadMembersAndInvitations()
        }
    }

    private func loadMembersAndInvitations() async {
        await viewModel.loadWorkspaceMembers(appState: appState)
        await viewModel.loadWorkspaceInvitations(appState: appState)
    }

    private func showInviteSheet() {
        isShowingInviteSheet = true
    }

    private func changeRole(_ member: DocmostUser, _ role: String) {
        Task {
            await viewModel.changeWorkspaceMemberRole(member, role: role, appState: appState)
        }
    }

    private func activate(_ member: DocmostUser) {
        Task {
            await viewModel.activateWorkspaceMember(member, appState: appState)
        }
    }

    private func deactivate(_ member: DocmostUser) {
        Task {
            await viewModel.deactivateWorkspaceMember(member, appState: appState)
        }
    }

    private func confirmRemoval(_ member: DocmostUser) {
        memberToRemove = member
        isConfirmingRemoval = true
    }

    private func removeConfirmedMember() {
        guard let memberToRemove else { return }
        Task {
            await viewModel.deleteWorkspaceMember(memberToRemove, appState: appState)
            self.memberToRemove = nil
        }
    }

    private func cancelRemoval() {
        memberToRemove = nil
    }

    private func resendInvitation(_ invitation: DocmostWorkspaceInvitation) {
        Task {
            await viewModel.resendInvitation(invitation, appState: appState)
        }
    }

    private func confirmRevoke(_ invitation: DocmostWorkspaceInvitation) {
        invitationToRevoke = invitation
        isConfirmingRevoke = true
    }

    private func revokeConfirmedInvitation() {
        guard let invitationToRevoke else { return }
        Task {
            await viewModel.revokeInvitation(invitationToRevoke, appState: appState)
            self.invitationToRevoke = nil
        }
    }

    private func cancelRevoke() {
        invitationToRevoke = nil
    }
}
