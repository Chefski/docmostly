import Foundation

nonisolated struct SettingsRoleOption: Identifiable, Hashable, Sendable {
    let label: String
    let value: String
    let description: String

    var id: String {
        value
    }

    static let workspaceRoles = [
        SettingsRoleOption(label: "Owner", value: "owner", description: "Can manage workspace."),
        SettingsRoleOption(label: "Admin", value: "admin", description: "Can manage workspace but cannot delete it."),
        SettingsRoleOption(label: "Member", value: "member", description: "Can join groups and spaces.")
    ]

    static let spaceRoles = [
        SettingsRoleOption(label: "Full access", value: "admin", description: "Can manage settings and pages."),
        SettingsRoleOption(label: "Can edit", value: "writer", description: "Can create and edit pages."),
        SettingsRoleOption(label: "Can view", value: "reader", description: "Can view pages.")
    ]

    static func assignableWorkspaceRoles(isOwner: Bool) -> [SettingsRoleOption] {
        isOwner ? workspaceRoles : workspaceRoles.filter { $0.value != "owner" }
    }

    static func label(for value: String?, in roles: [SettingsRoleOption]) -> String {
        roles.first { $0.value == value }?.label ?? value ?? "Unknown"
    }
}

nonisolated extension UserUpdate {
    var hasChanges: Bool {
        name != nil ||
        email != nil ||
        locale != nil ||
        fullPageWidth != nil ||
        pageEditMode != nil ||
        editorToolbar != nil ||
        notificationPageUpdates != nil ||
        notificationPageUserMention != nil ||
        notificationCommentUserMention != nil ||
        notificationCommentCreated != nil ||
        notificationCommentResolved != nil
    }
}

nonisolated extension WorkspaceUpdate {
    var hasChanges: Bool {
        name != nil ||
        logo != nil ||
        emailDomains != nil ||
        enforceSso != nil ||
        enforceMfa != nil ||
        restrictApiToAdmins != nil ||
        aiSearch != nil ||
        generativeAi != nil ||
        disablePublicSharing != nil ||
        mcpEnabled != nil ||
        aiChat != nil ||
        trashRetentionDays != nil ||
        allowMemberTemplates != nil
    }
}
