import SwiftUI

struct SettingsRoleMenu: View {
    let title: String
    let selectedRole: String?
    let roles: [SettingsRoleOption]
    let isDisabled: Bool
    let select: (String) -> Void

    var body: some View {
        if isDisabled {
            Text(SettingsRoleOption.label(for: selectedRole, in: roles))
                .foregroundStyle(.secondary)
        } else {
            Menu {
                ForEach(roles) { role in
                    if role.value == selectedRole {
                        Button(role.label, systemImage: "checkmark") {
                            select(role.value)
                        }
                    } else {
                        Button(role.label) {
                            select(role.value)
                        }
                    }
                }
            } label: {
                Label(SettingsRoleOption.label(for: selectedRole, in: roles), systemImage: "chevron.up.chevron.down")
            }
            .accessibilityLabel(title)
        }
    }
}
