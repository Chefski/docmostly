nonisolated enum SpaceManagementAuthorization {
    static func canManageWorkspace(role: String?) -> Bool {
        role == "owner" || role == "admin"
    }

    static func canManageSpace(workspaceRole: String?, membershipRole: String?) -> Bool {
        canManageWorkspace(role: workspaceRole) || membershipRole == "admin"
    }
}
