import Foundation

extension AppState {
    func createPage(spaceId: String, parentPageId: String? = nil, title: String? = nil) async throws -> DocmostPage {
        guard let apiClient else {
            throw APIError.connectionFailed("Creating pages requires a network connection.")
        }

        let page: DocmostPage = try await apiClient.send(.createPage(
            spaceId: spaceId,
            parentPageId: parentPageId,
            title: title
        ))
        isOffline = false
        return page
    }

    func deletePage(pageId: String, permanentlyDelete: Bool = false) async throws {
        guard let apiClient else {
            throw APIError.connectionFailed("Deleting pages requires a network connection.")
        }

        try await apiClient.sendVoid(.deletePage(pageId: pageId, permanentlyDelete: permanentlyDelete))
        isOffline = false
    }

    func loadDeletedPages(spaceId: String) async throws -> [DocmostPage] {
        guard let apiClient else {
            throw APIError.connectionFailed("Trash requires a network connection.")
        }

        let response: PaginatedResponse<DocmostPage> = try await apiClient.send(.deletedPages(spaceId: spaceId))
        isOffline = false
        return response.items
    }

    func restorePage(pageId: String) async throws -> DocmostPage {
        guard let apiClient else {
            throw APIError.connectionFailed("Restoring pages requires a network connection.")
        }

        let page: DocmostPage = try await apiClient.send(.restorePage(pageId: pageId))
        isOffline = false
        return page
    }

    func movePage(_ payload: PageTreeMovePayload) async throws {
        let offlinePayload = OfflineMutationPayload.movePage(
            pageId: payload.pageId,
            parentPageId: payload.parentPageId,
            position: payload.position
        )

        guard let apiClient else {
            try await queueOfflineMutation(offlinePayload)
            return
        }

        guard pendingOfflineMutationCount == 0 else {
            try await queueOfflineMutation(offlinePayload)
            return
        }

        do {
            try await apiClient.sendVoid(.movePage(
                pageId: payload.pageId,
                parentPageId: payload.parentPageId,
                position: payload.position
            ))
            isOffline = false
            scheduleOfflineQueueReconciliation()
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            try await queueOfflineMutation(offlinePayload)
        }
    }

    func movePageToSpace(pageId: String, spaceId: String) async throws {
        let offlinePayload = OfflineMutationPayload.movePageToSpace(pageId: pageId, spaceId: spaceId)

        guard let apiClient else {
            try await queueOfflineMutation(offlinePayload)
            return
        }

        guard pendingOfflineMutationCount == 0 else {
            try await queueOfflineMutation(offlinePayload)
            return
        }

        do {
            try await apiClient.sendVoid(.movePageToSpace(pageId: pageId, spaceId: spaceId))
            isOffline = false
            scheduleOfflineQueueReconciliation()
        } catch {
            guard canQueueOfflineMutation(after: error) else { throw error }
            isOffline = true
            statusMessage = error.localizedDescription
            try await queueOfflineMutation(offlinePayload)
        }
    }

    func duplicatePage(pageId: String, spaceId: String? = nil) async throws -> DocmostPage {
        guard let apiClient else {
            throw APIError.connectionFailed("Duplicating pages requires a network connection.")
        }

        let page: DocmostPage = try await apiClient.send(.duplicatePage(pageId: pageId, spaceId: spaceId))
        isOffline = false
        return page
    }

    func createSpace(name: String, description: String?, slug: String) async throws -> DocmostSpace {
        guard let apiClient else {
            throw APIError.connectionFailed("Creating spaces requires a network connection.")
        }

        let space: DocmostSpace = try await apiClient.send(.createSpace(
            name: name,
            description: description,
            slug: slug
        ))
        spaces.append(space)
        spaces.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        selectSpace(id: space.id)
        isOffline = false
        return space
    }

    func updateSpace(spaceId: String, update: SpaceUpdate) async throws -> DocmostSpace {
        guard let apiClient else {
            throw APIError.connectionFailed("Updating spaces requires a network connection.")
        }

        let space: DocmostSpace = try await apiClient.send(.updateSpace(
            spaceId: spaceId,
            name: update.name,
            description: update.description,
            slug: update.slug,
            disablePublicSharing: update.disablePublicSharing,
            allowViewerComments: update.allowViewerComments
        ))
        if let index = spaces.firstIndex(where: { $0.id == space.id }) {
            spaces[index] = space
        }
        isOffline = false
        return space
    }

    func deleteSpace(spaceId: String) async throws {
        guard let apiClient else {
            throw APIError.connectionFailed("Deleting spaces requires a network connection.")
        }

        try await apiClient.sendVoid(.deleteSpace(spaceId: spaceId))
        spaces.removeAll { $0.id == spaceId }
        if selectedSpaceID == spaceId || selectedSidebarDestination == .space(spaceId) {
            resetNavigationSelection()
            selectDefaultSpaceIfNeeded()
        }
        isOffline = false
    }

    func loadSpaceMembers(spaceId: String) async throws -> [DocmostSpaceMember] {
        guard let apiClient else {
            throw APIError.connectionFailed("Space members require a network connection.")
        }

        let response: PaginatedResponse<DocmostSpaceMember> = try await apiClient.send(.spaceMembers(spaceId: spaceId))
        isOffline = false
        return response.items
    }

    func addSpaceMembers(spaceId: String, role: String, userIds: [String], groupIds: [String]) async throws {
        guard let apiClient else {
            throw APIError.connectionFailed("Adding members requires a network connection.")
        }

        try await apiClient.sendVoid(.addSpaceMembers(
            spaceId: spaceId,
            role: role,
            userIds: userIds,
            groupIds: groupIds
        ))
        isOffline = false
    }

    func changeSpaceMemberRole(spaceId: String, role: String, userId: String?, groupId: String?) async throws {
        guard let apiClient else {
            throw APIError.connectionFailed("Changing roles requires a network connection.")
        }

        try await apiClient.sendVoid(.changeSpaceMemberRole(
            spaceId: spaceId,
            role: role,
            userId: userId,
            groupId: groupId
        ))
        isOffline = false
    }

    func removeSpaceMember(spaceId: String, userId: String?, groupId: String?) async throws {
        guard let apiClient else {
            throw APIError.connectionFailed("Removing members requires a network connection.")
        }

        try await apiClient.sendVoid(.removeSpaceMember(spaceId: spaceId, userId: userId, groupId: groupId))
        isOffline = false
    }

    func loadWorkspaceInfo() async throws -> DocmostWorkspace {
        guard let apiClient else {
            throw APIError.connectionFailed("Workspace settings require a network connection.")
        }

        let workspace: DocmostWorkspace = try await apiClient.send(.workspaceInfo)
        if let currentUser {
            self.currentUser = CurrentUserResponse(user: currentUser.user, workspace: workspace)
        }
        isOffline = false
        return workspace
    }

    func updateWorkspace(_ update: WorkspaceUpdate) async throws -> DocmostWorkspace {
        guard let apiClient else {
            throw APIError.connectionFailed("Updating workspace settings requires a network connection.")
        }

        let workspace: DocmostWorkspace = try await apiClient.send(.updateWorkspace(update))
        if let currentUser {
            self.currentUser = CurrentUserResponse(user: currentUser.user, workspace: workspace)
        }
        isOffline = false
        return workspace
    }

    func updateUser(_ update: UserUpdate) async throws -> DocmostUser {
        guard let apiClient else {
            throw APIError.connectionFailed("Updating account settings requires a network connection.")
        }

        let user: DocmostUser = try await apiClient.send(.updateUser(update))
        if let currentUser {
            self.currentUser = CurrentUserResponse(user: user, workspace: currentUser.workspace)
        }
        isOffline = false
        return user
    }

    func loadWorkspaceMembers() async throws -> [DocmostUser] {
        guard let apiClient else {
            throw APIError.connectionFailed("Workspace members require a network connection.")
        }

        let response: PaginatedResponse<DocmostUser> = try await apiClient.send(.workspaceMembers())
        isOffline = false
        return response.items
    }

    func changeWorkspaceMemberRole(userId: String, role: String) async throws {
        guard let apiClient else {
            throw APIError.connectionFailed("Changing roles requires a network connection.")
        }

        try await apiClient.sendVoid(.changeWorkspaceMemberRole(userId: userId, role: role))
        isOffline = false
    }

    func loadWorkspaceInvitations() async throws -> [DocmostWorkspaceInvitation] {
        guard let apiClient else {
            throw APIError.connectionFailed("Workspace invitations require a network connection.")
        }

        let response: PaginatedResponse<DocmostWorkspaceInvitation> = try await apiClient.send(.workspaceInvitations())
        isOffline = false
        return response.items
    }

    func createWorkspaceInvitation(emails: [String], role: String, groupIds: [String]) async throws {
        guard let apiClient else {
            throw APIError.connectionFailed("Creating invitations requires a network connection.")
        }

        try await apiClient.sendVoid(.createWorkspaceInvitation(emails: emails, role: role, groupIds: groupIds))
        isOffline = false
    }

    func resendWorkspaceInvitation(invitationId: String) async throws {
        guard let apiClient else {
            throw APIError.connectionFailed("Resending invitations requires a network connection.")
        }

        try await apiClient.sendVoid(.resendWorkspaceInvitation(invitationId: invitationId))
        isOffline = false
    }

    func revokeWorkspaceInvitation(invitationId: String) async throws {
        guard let apiClient else {
            throw APIError.connectionFailed("Revoking invitations requires a network connection.")
        }

        try await apiClient.sendVoid(.revokeWorkspaceInvitation(invitationId: invitationId))
        isOffline = false
    }

    func loadWorkspaceInvitationLink(invitationId: String) async throws -> String {
        guard let apiClient else {
            throw APIError.connectionFailed("Invitation links require a network connection.")
        }

        let response: DocmostInvitationLink = try await apiClient.send(.workspaceInvitationLink(
            invitationId: invitationId
        ))
        isOffline = false
        return response.inviteLink
    }

    func deactivateWorkspaceMember(userId: String) async throws {
        guard let apiClient else {
            throw APIError.connectionFailed("Deactivating members requires a network connection.")
        }

        try await apiClient.sendVoid(.deactivateWorkspaceMember(userId: userId))
        isOffline = false
    }

    func activateWorkspaceMember(userId: String) async throws {
        guard let apiClient else {
            throw APIError.connectionFailed("Activating members requires a network connection.")
        }

        try await apiClient.sendVoid(.activateWorkspaceMember(userId: userId))
        isOffline = false
    }

    func deleteWorkspaceMember(userId: String) async throws {
        guard let apiClient else {
            throw APIError.connectionFailed("Deleting members requires a network connection.")
        }

        try await apiClient.sendVoid(.deleteWorkspaceMember(userId: userId))
        isOffline = false
    }

    func loadGroups() async throws -> [DocmostGroup] {
        guard let apiClient else {
            throw APIError.connectionFailed("Groups require a network connection.")
        }

        let response: PaginatedResponse<DocmostGroup> = try await apiClient.send(.groups())
        isOffline = false
        return response.items
    }

    func createGroup(name: String, description: String?) async throws -> DocmostGroup {
        guard let apiClient else {
            throw APIError.connectionFailed("Creating groups requires a network connection.")
        }

        let group: DocmostGroup = try await apiClient.send(.createGroup(name: name, description: description))
        isOffline = false
        return group
    }

    func updateGroup(groupId: String, name: String?, description: String?) async throws -> DocmostGroup {
        guard let apiClient else {
            throw APIError.connectionFailed("Updating groups requires a network connection.")
        }

        let group: DocmostGroup = try await apiClient.send(.updateGroup(
            groupId: groupId,
            name: name,
            description: description
        ))
        isOffline = false
        return group
    }

    func deleteGroup(groupId: String) async throws {
        guard let apiClient else {
            throw APIError.connectionFailed("Deleting groups requires a network connection.")
        }

        try await apiClient.sendVoid(.deleteGroup(groupId: groupId))
        isOffline = false
    }

    func loadGroupMembers(groupId: String) async throws -> [DocmostUser] {
        guard let apiClient else {
            throw APIError.connectionFailed("Group members require a network connection.")
        }

        let response: PaginatedResponse<DocmostUser> = try await apiClient.send(.groupMembers(groupId: groupId))
        isOffline = false
        return response.items
    }

    func addGroupMembers(groupId: String, userIds: [String]) async throws {
        guard let apiClient else {
            throw APIError.connectionFailed("Adding group members requires a network connection.")
        }

        try await apiClient.sendVoid(.addGroupMembers(groupId: groupId, userIds: userIds))
        isOffline = false
    }

    func removeGroupMember(groupId: String, userId: String) async throws {
        guard let apiClient else {
            throw APIError.connectionFailed("Removing group members requires a network connection.")
        }

        try await apiClient.sendVoid(.removeGroupMember(groupId: groupId, userId: userId))
        isOffline = false
    }
}
