import SwiftUI

struct WorkspaceInvitationRowView: View {
    let invitation: DocmostWorkspaceInvitation
    let canManage: Bool
    let resend: (DocmostWorkspaceInvitation) -> Void
    let revoke: (DocmostWorkspaceInvitation) -> Void

    var body: some View {
        HStack {
            Image(systemName: "envelope")
                .foregroundStyle(DocmostlyTheme.primary)
                .accessibilityHidden(true)

            VStack(alignment: .leading) {
                Text(invitation.email)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Text(SettingsRoleOption.label(for: invitation.role, in: SettingsRoleOption.workspaceRoles))
                .font(.footnote)
                .foregroundStyle(.secondary)

            if canManage {
                Menu("Invitation Actions", systemImage: "ellipsis.circle") {
                    Button("Resend", systemImage: "paperplane") {
                        resend(invitation)
                    }
                    Button("Revoke", systemImage: "trash", role: .destructive) {
                        revoke(invitation)
                    }
                }
                .labelStyle(.iconOnly)
            }
        }
    }

    private var detail: String {
        guard let createdAt = invitation.createdAt else { return "Pending" }
        return "Invited \(createdAt.formatted(date: .abbreviated, time: .shortened))"
    }
}
