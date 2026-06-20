import Foundation
import Testing
@testable import docmostly

struct SettingsDraftPayloadTests {
    @Test func accountDraftEncodesPreferenceAndNotificationUpdates() throws {
        var draft = AccountSettingsDraft(user: user())
        draft.fullPageWidth = true
        draft.notificationCommentResolved = false

        let body = try encodedDictionary(draft.update())

        #expect(body["name"] == nil)
        #expect(body["fullPageWidth"] as? Bool == true)
        #expect(body["notificationCommentResolved"] as? Bool == false)
        #expect(body["notificationPageUpdates"] == nil)
    }

    @Test func workspaceDraftEncodesOnlyChangedWorkspaceFields() throws {
        var draft = WorkspaceSettingsDraft(workspace: workspace())
        draft.name = "Docs"
        draft.disablePublicSharing = true
        draft.trashRetentionDays = 60

        let body = try encodedDictionary(draft.update(comparedTo: workspace()))

        #expect(body["name"] as? String == "Docs")
        #expect(body["disablePublicSharing"] as? Bool == true)
        #expect(body["trashRetentionDays"] as? Int == 60)
        #expect(body["restrictApiToAdmins"] == nil)
    }

    @Test func roleLabelsMirrorDocmostWeb() {
        #expect(SettingsRoleOption.workspaceRoles.map(\.value) == ["owner", "admin", "member"])
        #expect(SettingsRoleOption.assignableWorkspaceRoles(isOwner: false).map(\.value) == ["admin", "member"])
        #expect(SettingsRoleOption.spaceRoles.map(\.value) == ["admin", "writer", "reader"])
        #expect(SettingsRoleOption.label(for: "writer", in: SettingsRoleOption.spaceRoles) == "Can edit")
    }

    private func encodedDictionary<Value: Encodable>(_ value: Value) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func user() -> DocmostUser {
        DocmostUser(
            id: "user-1",
            name: "Chefling",
            email: "chefling@example.com",
            avatarUrl: nil,
            role: "admin",
            workspaceId: "workspace-1",
            locale: nil,
            timezone: nil,
            settings: DocmostUserSettings(
                preferences: DocmostUserPreferences(
                    fullPageWidth: false,
                    pageEditMode: "edit",
                    editorToolbar: true
                ),
                notifications: DocmostUserNotificationSettings(
                    pageUpdated: true,
                    pageUserMention: true,
                    commentUserMention: true,
                    commentCreated: true,
                    commentResolved: true
                )
            ),
            emailVerifiedAt: nil,
            invitedById: nil,
            lastLoginAt: nil,
            lastActiveAt: nil,
            createdAt: nil,
            updatedAt: nil,
            deactivatedAt: nil,
            deletedAt: nil,
            hasGeneratedPassword: nil
        )
    }

    private func workspace() -> DocmostWorkspace {
        DocmostWorkspace(
            id: "workspace-1",
            name: "Docmost",
            logo: nil,
            hostname: nil,
            description: nil,
            defaultSpaceId: nil,
            customDomain: nil,
            enableInvite: nil,
            status: nil,
            enforceSso: false,
            enforceMfa: false,
            emailDomains: nil,
            settings: DocmostWorkspaceSettings(
                artificialIntelligence: DocmostWorkspaceAISettings(
                    search: false,
                    generative: false,
                    mcp: false,
                    chat: false
                ),
                sharing: DocmostWorkspaceSharingSettings(disabled: false),
                api: DocmostWorkspaceAPISettings(restrictToAdmins: false),
                templates: DocmostWorkspaceTemplateSettings(allowMemberTemplates: true)
            ),
            memberCount: 1,
            plan: nil,
            aiSearch: false,
            generativeAi: false,
            disablePublicSharing: false,
            mcpEnabled: false,
            trashRetentionDays: 30,
            restrictApiToAdmins: false,
            allowMemberTemplates: true,
            isScimEnabled: nil
        )
    }
}
