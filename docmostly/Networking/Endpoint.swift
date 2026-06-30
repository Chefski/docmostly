import Foundation

// swiftlint:disable file_length type_body_length

nonisolated enum ContentFormat: String, Sendable {
    case json
    case markdown
    case html
}

nonisolated enum ContentOperation: String, Sendable {
    case append
    case prepend
    case replace
}

nonisolated enum Endpoint: Sendable {
    case workspacePublic
    case login(email: String, password: String)
    case logout
    case collabToken
    case currentUser
    case updateUser(UserUpdate)
    case spaces(query: String? = nil, cursor: String? = nil, limit: Int = 100)
    case spaceInfo(spaceId: String)
    case createSpace(name: String, description: String?, slug: String)
    case updateSpace(
        spaceId: String,
        name: String?,
        description: String?,
        slug: String?,
        disablePublicSharing: Bool?,
        allowViewerComments: Bool?
    )
    case deleteSpace(spaceId: String)
    case spaceMembers(spaceId: String, query: String? = nil, cursor: String? = nil, limit: Int = 50)
    case addSpaceMembers(spaceId: String, role: String, userIds: [String], groupIds: [String])
    case removeSpaceMember(spaceId: String, userId: String? = nil, groupId: String? = nil)
    case changeSpaceMemberRole(spaceId: String, role: String, userId: String? = nil, groupId: String? = nil)
    case sidebarPages(spaceId: String? = nil, pageId: String? = nil, cursor: String? = nil, limit: Int = 100)
    case pageInfo(pageId: String, format: ContentFormat = .html)
    case createPage(
        spaceId: String,
        parentPageId: String? = nil,
        title: String? = nil,
        icon: String? = nil,
        content: ProseMirrorDocument? = nil,
        format: ContentFormat = .json
    )
    case deletePage(pageId: String, permanentlyDelete: Bool = false)
    case deletedPages(spaceId: String, cursor: String? = nil, limit: Int = 50)
    case restorePage(pageId: String)
    case movePage(pageId: String, parentPageId: String?, position: String)
    case movePageToSpace(pageId: String, spaceId: String)
    case duplicatePage(pageId: String, spaceId: String? = nil)
    case pageBreadcrumbs(pageId: String)
    case recentPages(spaceId: String? = nil, cursor: String? = nil, limit: Int = 20)
    case favorites(type: FavoriteType? = nil, spaceId: String? = nil, cursor: String? = nil, limit: Int = 20)
    case favoriteIds(type: FavoriteType, spaceId: String? = nil)
    case addFavorite(type: FavoriteType, pageId: String? = nil, spaceId: String? = nil, templateId: String? = nil)
    case removeFavorite(type: FavoriteType, pageId: String? = nil, spaceId: String? = nil, templateId: String? = nil)
    case notifications(type: NotificationListType = .all, cursor: String? = nil, limit: Int = 20)
    case unreadNotificationCount
    case markNotificationsRead(notificationIds: [String])
    case markAllNotificationsRead
    case pageLabels(pageId: String)
    case workspaceLabels(type: LabelType = .page, query: String? = nil, cursor: String? = nil, limit: Int = 50)
    case addPageLabels(pageId: String, names: [String])
    case removePageLabel(pageId: String, labelId: String)
    case labelPages(
        labelId: String? = nil,
        name: String? = nil,
        spaceId: String? = nil,
        query: String? = nil,
        cursor: String? = nil,
        limit: Int = 20
    )
    case watchPage(pageId: String)
    case unwatchPage(pageId: String)
    case pageWatchStatus(pageId: String)
    case watchedSpaceIds
    case watchSpace(spaceId: String)
    case unwatchSpace(spaceId: String)
    case spaceWatchStatus(spaceId: String)
    case search(query: String, spaceId: String? = nil, limit: Int = 20)
    case searchSuggestions(
        query: String,
        includeUsers: Bool = true,
        includePages: Bool = true,
        spaceId: String? = nil,
        limit: Int = 10
    )
    case createBase(parentPageId: String, template: DocmostBaseTemplate? = nil)
    case updatePage(
        pageId: String,
        title: String? = nil,
        content: ProseMirrorDocument? = nil,
        format: ContentFormat = .json,
        operation: ContentOperation = .replace
    )
    case comments(pageId: String, cursor: String? = nil, limit: Int = 100)
    case createComment(
        pageId: String,
        content: String,
        type: DocmostCommentType = .page,
        selection: String? = nil,
        yjsSelection: NativeEditorYjsSelection? = nil
    )
    case resolveComment(commentId: String, pageId: String, resolved: Bool)
    case attachmentInfo(attachmentId: String)
    case workspaceInfo
    case updateWorkspace(WorkspaceUpdate)
    case workspaceMembers(query: String? = nil, cursor: String? = nil, limit: Int = 50)
    case deactivateWorkspaceMember(userId: String)
    case activateWorkspaceMember(userId: String)
    case deleteWorkspaceMember(userId: String)
    case changeWorkspaceMemberRole(userId: String, role: String)
    case workspaceInvitations(cursor: String? = nil, limit: Int = 50)
    case createWorkspaceInvitation(emails: [String], role: String, groupIds: [String])
    case resendWorkspaceInvitation(invitationId: String)
    case revokeWorkspaceInvitation(invitationId: String)
    case workspaceInvitationLink(invitationId: String)
    case groups(query: String? = nil, cursor: String? = nil, limit: Int = 50)
    case groupInfo(groupId: String)
    case createGroup(name: String, description: String? = nil, userIds: [String]? = nil)
    case updateGroup(groupId: String, name: String? = nil, description: String? = nil, userIds: [String]? = nil)
    case deleteGroup(groupId: String)
    case groupMembers(groupId: String, query: String? = nil, cursor: String? = nil, limit: Int = 50)
    case addGroupMembers(groupId: String, userIds: [String])
    case removeGroupMember(groupId: String, userId: String)

    func urlRequest(baseURL: URL) throws -> URLRequest {
        let url = baseURL
            .appending(path: AppConfig.apiPathPrefix)
            .appending(path: path)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = try bodyData()
        if request.httpBody != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    private var path: String {
        switch self {
        case .workspacePublic:
            "workspace/public"
        case .login:
            "auth/login"
        case .logout:
            "auth/logout"
        case .collabToken:
            "auth/collab-token"
        case .currentUser:
            "users/me"
        case .updateUser:
            "users/update"
        case .spaces:
            "spaces"
        case .spaceInfo:
            "spaces/info"
        case .createSpace:
            "spaces/create"
        case .updateSpace:
            "spaces/update"
        case .deleteSpace:
            "spaces/delete"
        case .spaceMembers:
            "spaces/members"
        case .addSpaceMembers:
            "spaces/members/add"
        case .removeSpaceMember:
            "spaces/members/remove"
        case .changeSpaceMemberRole:
            "spaces/members/change-role"
        case .sidebarPages:
            "pages/sidebar-pages"
        case .pageInfo:
            "pages/info"
        case .createPage:
            "pages/create"
        case .deletePage:
            "pages/delete"
        case .deletedPages:
            "pages/trash"
        case .restorePage:
            "pages/restore"
        case .movePage:
            "pages/move"
        case .movePageToSpace:
            "pages/move-to-space"
        case .duplicatePage:
            "pages/duplicate"
        case .pageBreadcrumbs:
            "pages/breadcrumbs"
        case .recentPages:
            "pages/recent"
        case .favorites:
            "favorites"
        case .favoriteIds:
            "favorites/ids"
        case .addFavorite:
            "favorites/add"
        case .removeFavorite:
            "favorites/remove"
        case .notifications:
            "notifications"
        case .unreadNotificationCount:
            "notifications/unread-count"
        case .markNotificationsRead:
            "notifications/mark-read"
        case .markAllNotificationsRead:
            "notifications/mark-all-read"
        case .pageLabels:
            "pages/labels"
        case .workspaceLabels:
            "labels"
        case .addPageLabels:
            "pages/labels/add"
        case .removePageLabel:
            "pages/labels/remove"
        case .labelPages:
            "labels/pages"
        case .watchPage:
            "pages/watch"
        case .unwatchPage:
            "pages/unwatch"
        case .pageWatchStatus:
            "pages/watch-status"
        case .watchedSpaceIds:
            "spaces/watched-ids"
        case .watchSpace:
            "spaces/watch"
        case .unwatchSpace:
            "spaces/unwatch"
        case .spaceWatchStatus:
            "spaces/watch-status"
        case .search:
            "search"
        case .searchSuggestions:
            "search/suggest"
        case .createBase:
            "bases/create"
        case .updatePage:
            "pages/update"
        case .comments:
            "comments"
        case .createComment:
            "comments/create"
        case .resolveComment:
            "comments/resolve"
        case .attachmentInfo:
            "files/info"
        case .workspaceInfo:
            "workspace/info"
        case .updateWorkspace:
            "workspace/update"
        case .workspaceMembers:
            "workspace/members"
        case .deactivateWorkspaceMember:
            "workspace/members/deactivate"
        case .activateWorkspaceMember:
            "workspace/members/activate"
        case .deleteWorkspaceMember:
            "workspace/members/delete"
        case .changeWorkspaceMemberRole:
            "workspace/members/change-role"
        case .workspaceInvitations:
            "workspace/invites"
        case .createWorkspaceInvitation:
            "workspace/invites/create"
        case .resendWorkspaceInvitation:
            "workspace/invites/resend"
        case .revokeWorkspaceInvitation:
            "workspace/invites/revoke"
        case .workspaceInvitationLink:
            "workspace/invites/link"
        case .groups:
            "groups"
        case .groupInfo:
            "groups/info"
        case .createGroup:
            "groups/create"
        case .updateGroup:
            "groups/update"
        case .deleteGroup:
            "groups/delete"
        case .groupMembers:
            "groups/members"
        case .addGroupMembers:
            "groups/members/add"
        case .removeGroupMember:
            "groups/members/remove"
        }
    }

    // Keep this switch exhaustive so every endpoint's request body is visible in one place.
    // swiftlint:disable cyclomatic_complexity function_body_length
    private func bodyData() throws -> Data? {
        switch self {
        case .workspacePublic, .logout, .collabToken, .currentUser, .workspaceInfo,
                .unreadNotificationCount, .markAllNotificationsRead, .watchedSpaceIds:
            return nil
        case .login(let email, let password):
            return try encode(LoginRequest(email: email, password: password))
        case .updateUser(let update):
            return try encode(update)
        case .spaces(let query, let cursor, let limit):
            return try encode(PaginationRequest(query: query, cursor: cursor, limit: limit))
        case .spaceInfo(let spaceId):
            return try encode(SpaceInfoRequest(spaceId: spaceId))
        case .createSpace(let name, let description, let slug):
            return try encode(CreateSpaceRequest(name: name, description: description, slug: slug))
        case .updateSpace(let spaceId, let name, let description, let slug, let disablePublicSharing,
                let allowViewerComments):
            return try encode(UpdateSpaceRequest(
                spaceId: spaceId,
                name: name,
                description: description,
                slug: slug,
                disablePublicSharing: disablePublicSharing,
                allowViewerComments: allowViewerComments
            ))
        case .deleteSpace(let spaceId):
            return try encode(SpaceInfoRequest(spaceId: spaceId))
        case .spaceMembers(let spaceId, let query, let cursor, let limit):
            return try encode(SpaceMembersRequest(spaceId: spaceId, query: query, cursor: cursor, limit: limit))
        case .addSpaceMembers(let spaceId, let role, let userIds, let groupIds):
            return try encode(AddSpaceMembersRequest(
                spaceId: spaceId,
                role: role,
                userIds: userIds,
                groupIds: groupIds
            ))
        case .removeSpaceMember(let spaceId, let userId, let groupId):
            return try encode(SpaceMemberRequest(spaceId: spaceId, userId: userId, groupId: groupId))
        case .changeSpaceMemberRole(let spaceId, let role, let userId, let groupId):
            return try encode(SpaceMemberRoleRequest(
                spaceId: spaceId,
                role: role,
                userId: userId,
                groupId: groupId
            ))
        case .sidebarPages(let spaceId, let pageId, let cursor, let limit):
            return try encode(SidebarPagesRequest(spaceId: spaceId, pageId: pageId, cursor: cursor, limit: limit))
        case .pageInfo(let pageId, let format):
            return try encode(PageInfoRequest(pageId: pageId, format: format.rawValue))
        case .createPage(let spaceId, let parentPageId, let title, let icon, let content, let format):
            return try encode(CreatePageRequest(
                title: title,
                icon: icon,
                parentPageId: parentPageId,
                spaceId: spaceId,
                content: content,
                format: content == nil ? nil : format.rawValue
            ))
        case .deletePage(let pageId, let permanentlyDelete):
            return try encode(DeletePageRequest(pageId: pageId, permanentlyDelete: permanentlyDelete))
        case .deletedPages(let spaceId, let cursor, let limit):
            return try encode(DeletedPagesRequest(spaceId: spaceId, cursor: cursor, limit: limit))
        case .restorePage(let pageId):
            return try encode(PageIDRequest(pageId: pageId))
        case .movePage(let pageId, let parentPageId, let position):
            return try encode(MovePageRequest(pageId: pageId, position: position, parentPageId: parentPageId))
        case .movePageToSpace(let pageId, let spaceId):
            return try encode(MovePageToSpaceRequest(pageId: pageId, spaceId: spaceId))
        case .duplicatePage(let pageId, let spaceId):
            return try encode(DuplicatePageRequest(pageId: pageId, spaceId: spaceId))
        case .pageBreadcrumbs(let pageId):
            return try encode(PageIDRequest(pageId: pageId))
        case .recentPages(let spaceId, let cursor, let limit):
            return try encode(RecentPagesRequest(spaceId: spaceId, cursor: cursor, limit: limit))
        case .favorites(let type, let spaceId, let cursor, let limit):
            return try encode(FavoritesRequest(
                type: type?.rawValue,
                spaceId: spaceId,
                cursor: cursor,
                limit: limit
            ))
        case .favoriteIds(let type, let spaceId):
            return try encode(FavoriteIdsRequest(type: type.rawValue, spaceId: spaceId))
        case .addFavorite(let type, let pageId, let spaceId, let templateId),
                .removeFavorite(let type, let pageId, let spaceId, let templateId):
            return try encode(FavoriteMutationRequest(
                type: type.rawValue,
                pageId: pageId,
                spaceId: spaceId,
                templateId: templateId
            ))
        case .notifications(let type, let cursor, let limit):
            return try encode(NotificationsRequest(type: type.rawValue, cursor: cursor, limit: limit))
        case .markNotificationsRead(let notificationIds):
            return try encode(MarkNotificationsReadRequest(notificationIds: notificationIds))
        case .pageLabels(let pageId):
            return try encode(PageIDRequest(pageId: pageId))
        case .workspaceLabels(let type, let query, let cursor, let limit):
            return try encode(LabelsRequest(
                type: type.rawValue,
                query: query,
                cursor: cursor,
                limit: limit
            ))
        case .addPageLabels(let pageId, let names):
            return try encode(AddPageLabelsRequest(pageId: pageId, names: names))
        case .removePageLabel(let pageId, let labelId):
            return try encode(RemovePageLabelRequest(pageId: pageId, labelId: labelId))
        case .labelPages(let labelId, let name, let spaceId, let query, let cursor, let limit):
            return try encode(LabelPagesRequest(
                labelId: labelId,
                name: name,
                spaceId: spaceId,
                query: query,
                cursor: cursor,
                limit: limit
            ))
        case .watchPage(let pageId), .unwatchPage(let pageId), .pageWatchStatus(let pageId):
            return try encode(PageIDRequest(pageId: pageId))
        case .watchSpace(let spaceId), .unwatchSpace(let spaceId), .spaceWatchStatus(let spaceId):
            return try encode(SpaceInfoRequest(spaceId: spaceId))
        case .search(let query, let spaceId, let limit):
            return try encode(SearchRequest(query: query, spaceId: spaceId, limit: limit))
        case .searchSuggestions(let query, let includeUsers, let includePages, let spaceId, let limit):
            return try encode(SearchSuggestionsRequest(
                query: query,
                includeUsers: includeUsers,
                includePages: includePages,
                spaceId: spaceId,
                limit: limit
            ))
        case .createBase(let parentPageId, let template):
            return try encode(CreateBaseRequest(parentPageId: parentPageId, template: template))
        case .updatePage(let pageId, let title, let content, let format, let operation):
            let hasContent: Bool
            if case .some = content {
                hasContent = true
            } else {
                hasContent = false
            }
            return try encode(UpdatePageRequest(
                pageId: pageId,
                title: title,
                content: content,
                operation: hasContent ? operation.rawValue : nil,
                format: hasContent ? format.rawValue : nil
            ))
        case .comments(let pageId, let cursor, let limit):
            return try encode(CommentsRequest(pageId: pageId, cursor: cursor, limit: limit))
        case .createComment(let pageId, let content, let type, let selection, let yjsSelection):
            return try encode(CreateCommentRequest(
                pageId: pageId,
                content: content,
                type: type,
                selection: selection,
                yjsSelection: yjsSelection
            ))
        case .resolveComment(let commentId, let pageId, let resolved):
            return try encode(ResolveCommentRequest(
                commentId: commentId,
                pageId: pageId,
                resolved: resolved
            ))
        case .attachmentInfo(let attachmentId):
            return try encode(AttachmentInfoRequest(attachmentId: attachmentId))
        case .updateWorkspace(let update):
            return try encode(update)
        case .workspaceMembers(let query, let cursor, let limit):
            return try encode(PaginationRequest(query: query, cursor: cursor, limit: limit))
        case .deactivateWorkspaceMember(let userId), .activateWorkspaceMember(let userId),
                .deleteWorkspaceMember(let userId):
            return try encode(UserIDRequest(userId: userId))
        case .changeWorkspaceMemberRole(let userId, let role):
            return try encode(WorkspaceMemberRoleRequest(userId: userId, role: role))
        case .workspaceInvitations(let cursor, let limit):
            return try encode(PaginationRequest(query: nil, cursor: cursor, limit: limit))
        case .createWorkspaceInvitation(let emails, let role, let groupIds):
            return try encode(CreateWorkspaceInvitationRequest(emails: emails, groupIds: groupIds, role: role))
        case .resendWorkspaceInvitation(let invitationId), .revokeWorkspaceInvitation(let invitationId),
                .workspaceInvitationLink(let invitationId):
            return try encode(InvitationIDRequest(invitationId: invitationId))
        case .groups(let query, let cursor, let limit):
            return try encode(PaginationRequest(query: query, cursor: cursor, limit: limit))
        case .groupInfo(let groupId):
            return try encode(GroupIDRequest(groupId: groupId))
        case .createGroup(let name, let description, let userIds):
            return try encode(GroupRequest(name: name, description: description, userIds: userIds))
        case .updateGroup(let groupId, let name, let description, let userIds):
            return try encode(UpdateGroupRequest(
                groupId: groupId,
                name: name,
                description: description,
                userIds: userIds
            ))
        case .deleteGroup(let groupId):
            return try encode(GroupIDRequest(groupId: groupId))
        case .groupMembers(let groupId, let query, let cursor, let limit):
            return try encode(GroupMembersRequest(groupId: groupId, query: query, cursor: cursor, limit: limit))
        case .addGroupMembers(let groupId, let userIds):
            return try encode(AddGroupMembersRequest(groupId: groupId, userIds: userIds))
        case .removeGroupMember(let groupId, let userId):
            return try encode(GroupMemberRequest(groupId: groupId, userId: userId))
        }
    }
    // swiftlint:enable cyclomatic_complexity function_body_length

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        return try encoder.encode(value)
    }
}

nonisolated private struct LoginRequest: Encodable {
    let email: String
    let password: String
}

nonisolated struct UserUpdate: Encodable, Sendable {
    var name: String?
    var email: String?
    var locale: String?
    var fullPageWidth: Bool?
    var pageEditMode: String?
    var editorToolbar: Bool?
    var notificationPageUpdates: Bool?
    var notificationPageUserMention: Bool?
    var notificationCommentUserMention: Bool?
    var notificationCommentCreated: Bool?
    var notificationCommentResolved: Bool?
}

nonisolated struct WorkspaceUpdate: Encodable, Sendable {
    var name: String?
    var logo: String?
    var emailDomains: [String]?
    var enforceSso: Bool?
    var enforceMfa: Bool?
    var restrictApiToAdmins: Bool?
    var aiSearch: Bool?
    var generativeAi: Bool?
    var disablePublicSharing: Bool?
    var mcpEnabled: Bool?
    var aiChat: Bool?
    var trashRetentionDays: Int?
    var allowMemberTemplates: Bool?
}

nonisolated private struct PaginationRequest: Encodable {
    let query: String?
    let cursor: String?
    let limit: Int
}

nonisolated private struct SpaceInfoRequest: Encodable {
    let spaceId: String
}

nonisolated private struct CreateSpaceRequest: Encodable {
    let name: String
    let description: String?
    let slug: String
}

nonisolated private struct UpdateSpaceRequest: Encodable {
    let spaceId: String
    let name: String?
    let description: String?
    let slug: String?
    let disablePublicSharing: Bool?
    let allowViewerComments: Bool?
}

nonisolated private struct SpaceMembersRequest: Encodable {
    let spaceId: String
    let query: String?
    let cursor: String?
    let limit: Int
}

nonisolated private struct AddSpaceMembersRequest: Encodable {
    let spaceId: String
    let role: String
    let userIds: [String]
    let groupIds: [String]
}

nonisolated private struct SpaceMemberRequest: Encodable {
    let spaceId: String
    let userId: String?
    let groupId: String?
}

nonisolated private struct SpaceMemberRoleRequest: Encodable {
    let spaceId: String
    let role: String
    let userId: String?
    let groupId: String?
}

nonisolated private struct SidebarPagesRequest: Encodable {
    let spaceId: String?
    let pageId: String?
    let cursor: String?
    let limit: Int
}

nonisolated private struct PageInfoRequest: Encodable {
    let pageId: String
    let format: String
}

nonisolated private struct PageIDRequest: Encodable {
    let pageId: String
}

nonisolated private struct CreatePageRequest: Encodable {
    let title: String?
    let icon: String?
    let parentPageId: String?
    let spaceId: String
    let content: ProseMirrorDocument?
    let format: String?
}

nonisolated private struct DeletePageRequest: Encodable {
    let pageId: String
    let permanentlyDelete: Bool
}

nonisolated private struct DeletedPagesRequest: Encodable {
    let spaceId: String
    let cursor: String?
    let limit: Int
}

nonisolated private struct MovePageRequest: Encodable {
    let pageId: String
    let position: String
    let parentPageId: String?
}

nonisolated private struct MovePageToSpaceRequest: Encodable {
    let pageId: String
    let spaceId: String
}

nonisolated private struct DuplicatePageRequest: Encodable {
    let pageId: String
    let spaceId: String?
}

nonisolated private struct RecentPagesRequest: Encodable {
    let spaceId: String?
    let cursor: String?
    let limit: Int
}

nonisolated private struct FavoritesRequest: Encodable {
    let type: String?
    let spaceId: String?
    let cursor: String?
    let limit: Int
}

nonisolated private struct FavoriteIdsRequest: Encodable {
    let type: String
    let spaceId: String?
}

nonisolated private struct FavoriteMutationRequest: Encodable {
    let type: String
    let pageId: String?
    let spaceId: String?
    let templateId: String?
}

nonisolated private struct NotificationsRequest: Encodable {
    let type: String
    let cursor: String?
    let limit: Int
}

nonisolated private struct MarkNotificationsReadRequest: Encodable {
    let notificationIds: [String]
}

nonisolated private struct LabelsRequest: Encodable {
    let type: String
    let query: String?
    let cursor: String?
    let limit: Int
}

nonisolated private struct AddPageLabelsRequest: Encodable {
    let pageId: String
    let names: [String]
}

nonisolated private struct RemovePageLabelRequest: Encodable {
    let pageId: String
    let labelId: String
}

nonisolated private struct LabelPagesRequest: Encodable {
    let labelId: String?
    let name: String?
    let spaceId: String?
    let query: String?
    let cursor: String?
    let limit: Int
}

nonisolated private struct SearchRequest: Encodable {
    let query: String
    let spaceId: String?
    let limit: Int
}

nonisolated private struct SearchSuggestionsRequest: Encodable {
    let query: String
    let includeUsers: Bool
    let includePages: Bool
    let spaceId: String?
    let limit: Int
}

nonisolated private struct CreateBaseRequest: Encodable {
    let parentPageId: String
    let template: DocmostBaseTemplate?
}

nonisolated private struct UpdatePageRequest: Encodable {
    let pageId: String
    let title: String?
    let content: ProseMirrorDocument?
    let operation: String?
    let format: String?
}

nonisolated private struct CommentsRequest: Encodable {
    let pageId: String
    let cursor: String?
    let limit: Int
}

nonisolated private struct CreateCommentRequest: Encodable {
    let pageId: String
    let content: String
    let type: DocmostCommentType
    let selection: String?
    let yjsSelection: NativeEditorYjsSelection?
}

nonisolated private struct ResolveCommentRequest: Encodable {
    let commentId: String
    let pageId: String
    let resolved: Bool
}

nonisolated private struct AttachmentInfoRequest: Encodable {
    let attachmentId: String
}

nonisolated private struct UserIDRequest: Encodable {
    let userId: String
}

nonisolated private struct WorkspaceMemberRoleRequest: Encodable {
    let userId: String
    let role: String
}

nonisolated private struct CreateWorkspaceInvitationRequest: Encodable {
    let emails: [String]
    let groupIds: [String]
    let role: String
}

nonisolated private struct InvitationIDRequest: Encodable {
    let invitationId: String
}

nonisolated private struct GroupIDRequest: Encodable {
    let groupId: String
}

nonisolated private struct GroupRequest: Encodable {
    let name: String
    let description: String?
    let userIds: [String]?
}

nonisolated private struct UpdateGroupRequest: Encodable {
    let groupId: String
    let name: String?
    let description: String?
    let userIds: [String]?
}

nonisolated private struct GroupMembersRequest: Encodable {
    let groupId: String
    let query: String?
    let cursor: String?
    let limit: Int
}

nonisolated private struct AddGroupMembersRequest: Encodable {
    let groupId: String
    let userIds: [String]
}

nonisolated private struct GroupMemberRequest: Encodable {
    let groupId: String
    let userId: String
}

// swiftlint:enable file_length type_body_length
