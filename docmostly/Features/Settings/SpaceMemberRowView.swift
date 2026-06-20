import SwiftUI

struct SpaceMemberRowView: View {
    let member: DocmostSpaceMember
    let canManage: Bool
    let changeRole: (DocmostSpaceMember, String) -> Void
    let remove: (DocmostSpaceMember) -> Void

    var body: some View {
        HStack {
            Image(systemName: member.type == "group" ? "person.3" : "person.crop.circle")
                .foregroundStyle(DocmostlyTheme.primary)
                .accessibilityHidden(true)

            VStack(alignment: .leading) {
                Text(member.name)
                if let detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            SettingsRoleMenu(
                title: "Space role",
                selectedRole: member.role,
                roles: SettingsRoleOption.spaceRoles,
                isDisabled: canManage == false
            ) { role in
                changeRole(member, role)
            }

            if canManage {
                Menu("Member Actions", systemImage: "ellipsis.circle") {
                    Button("Remove", systemImage: "trash", role: .destructive) {
                        remove(member)
                    }
                }
                .labelStyle(.iconOnly)
            }
        }
    }

    private var detail: String? {
        if member.type == "group" {
            return "\(member.memberCount ?? 0) members"
        }
        return member.email
    }
}
