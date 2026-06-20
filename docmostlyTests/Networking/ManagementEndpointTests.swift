import Foundation
import Testing
@testable import docmostly

struct ManagementEndpointTests {
    @Test func buildsPageManagementRequests() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))

        let create = try Endpoint.createPage(
            spaceId: "space-1",
            parentPageId: "parent-1",
            title: "Roadmap"
        ).urlRequest(baseURL: baseURL)
        #expect(create.url?.absoluteString == "https://docs.example.com/api/pages/create")
        let createBody = try jsonBody(create)
        #expect(createBody["spaceId"] as? String == "space-1")
        #expect(createBody["parentPageId"] as? String == "parent-1")
        #expect(createBody["title"] as? String == "Roadmap")

        let move = try Endpoint.movePage(
            pageId: "page-1",
            parentPageId: "parent-2",
            position: "a000001"
        ).urlRequest(baseURL: baseURL)
        #expect(move.url?.absoluteString == "https://docs.example.com/api/pages/move")
        let moveBody = try jsonBody(move)
        #expect(moveBody["pageId"] as? String == "page-1")
        #expect(moveBody["parentPageId"] as? String == "parent-2")
        #expect(moveBody["position"] as? String == "a000001")

        let trash = try Endpoint.deletedPages(spaceId: "space-1").urlRequest(baseURL: baseURL)
        #expect(trash.url?.absoluteString == "https://docs.example.com/api/pages/trash")
        #expect(try jsonBody(trash)["spaceId"] as? String == "space-1")

        let delete = try Endpoint.deletePage(pageId: "page-1", permanentlyDelete: false)
            .urlRequest(baseURL: baseURL)
        #expect(delete.url?.absoluteString == "https://docs.example.com/api/pages/delete")
        #expect(try jsonBody(delete)["permanentlyDelete"] as? Bool == false)
    }

    @Test func buildsSpaceManagementRequests() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))

        let create = try Endpoint.createSpace(
            name: "Design",
            description: "Team docs",
            slug: "design"
        ).urlRequest(baseURL: baseURL)
        #expect(create.url?.absoluteString == "https://docs.example.com/api/spaces/create")
        let createBody = try jsonBody(create)
        #expect(createBody["name"] as? String == "Design")
        #expect(createBody["description"] as? String == "Team docs")
        #expect(createBody["slug"] as? String == "design")

        let update = try Endpoint.updateSpace(
            spaceId: "space-1",
            name: "Product",
            description: "Product docs",
            slug: "product",
            disablePublicSharing: true,
            allowViewerComments: false
        ).urlRequest(baseURL: baseURL)
        #expect(update.url?.absoluteString == "https://docs.example.com/api/spaces/update")
        let updateBody = try jsonBody(update)
        #expect(updateBody["spaceId"] as? String == "space-1")
        #expect(updateBody["slug"] as? String == "product")
        #expect(updateBody["disablePublicSharing"] as? Bool == true)
        #expect(updateBody["allowViewerComments"] as? Bool == false)

        let member = try Endpoint.changeSpaceMemberRole(
            spaceId: "space-1",
            role: "admin",
            userId: "user-1",
            groupId: nil
        )
            .urlRequest(baseURL: baseURL)
        #expect(member.url?.absoluteString == "https://docs.example.com/api/spaces/members/change-role")
        let memberBody = try jsonBody(member)
        #expect(memberBody["userId"] as? String == "user-1")
        #expect(memberBody["role"] as? String == "admin")
    }

    @Test func buildsWorkspaceAndGroupManagementRequests() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))

        let workspace = try Endpoint.updateWorkspace(WorkspaceUpdate(
            name: "Jumpseat",
            logo: "✈️"
        )).urlRequest(baseURL: baseURL)
        #expect(workspace.url?.absoluteString == "https://docs.example.com/api/workspace/update")
        #expect(try jsonBody(workspace)["name"] as? String == "Jumpseat")

        let role = try Endpoint.changeWorkspaceMemberRole(userId: "user-1", role: "admin")
            .urlRequest(baseURL: baseURL)
        #expect(role.url?.absoluteString == "https://docs.example.com/api/workspace/members/change-role")
        let roleBody = try jsonBody(role)
        #expect(roleBody["userId"] as? String == "user-1")
        #expect(roleBody["role"] as? String == "admin")

        let invite = try Endpoint.createWorkspaceInvitation(
            emails: ["alice@example.com"],
            role: "member",
            groupIds: ["group-1"]
        ).urlRequest(baseURL: baseURL)
        #expect(invite.url?.absoluteString == "https://docs.example.com/api/workspace/invites/create")
        let inviteBody = try jsonBody(invite)
        #expect(inviteBody["emails"] as? [String] == ["alice@example.com"])
        #expect(inviteBody["role"] as? String == "member")

        let group = try Endpoint.createGroup(name: "Editors", description: "Can edit docs")
            .urlRequest(baseURL: baseURL)
        #expect(group.url?.absoluteString == "https://docs.example.com/api/groups/create")
        #expect(try jsonBody(group)["description"] as? String == "Can edit docs")
    }

    private func jsonBody(_ request: URLRequest) throws -> [String: Any] {
        let body = try #require(request.httpBody)
        return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }
}
