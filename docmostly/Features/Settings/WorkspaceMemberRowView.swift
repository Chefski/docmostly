import SwiftUI

struct WorkspaceMemberRowView: View {
    let member: DocmostUser
    let canManage: Bool
    let roles: [SettingsRoleOption]
    let changeRole: (DocmostUser, String) -> Void
    let activate: (DocmostUser) -> Void
    let deactivate: (DocmostUser) -> Void
    let remove: (DocmostUser) -> Void

    var body: some View {
        HStack {
            Image(systemName: member.deactivatedAt == nil ? "person.crop.circle" : "person.crop.circle.badge.xmark")
                .foregroundStyle(member.deactivatedAt == nil ? DocmostlyTheme.primary : .secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading) {
                Text(member.name)
                if let email = member.email {
                    Text(email)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            SettingsRoleMenu(
                title: "Workspace role",
                selectedRole: member.role,
                roles: roles,
                isDisabled: canManage == false
            ) { role in
                changeRole(member, role)
            }

            if canManage {
                Menu("Member Actions", systemImage: "ellipsis.circle") {
                    if member.deactivatedAt == nil {
                        Button("Deactivate", systemImage: "pause.circle") {
                            deactivate(member)
                        }
                    } else {
                        Button("Activate", systemImage: "play.circle") {
                            activate(member)
                        }
                    }
                    Button("Remove", systemImage: "trash", role: .destructive) {
                        remove(member)
                    }
                }
                .labelStyle(.iconOnly)
            }
        }
    }
}
