import Testing
@testable import docmostly

struct SpaceManagementAuthorizationTests {
    @Test(arguments: ["owner", "admin"])
    func workspaceAdministratorsCanManageSpaces(_ workspaceRole: String) {
        #expect(
            SpaceManagementAuthorization.canManageSpace(
                workspaceRole: workspaceRole,
                membershipRole: nil
            )
        )
    }

    @Test func spaceAdministratorsCanManageTheirSpace() {
        #expect(
            SpaceManagementAuthorization.canManageSpace(
                workspaceRole: "member",
                membershipRole: "admin"
            )
        )
    }

    @Test(arguments: ["reader", "writer"])
    func nonAdministrativeSpaceMembersCannotManageSpaces(_ membershipRole: String) {
        #expect(
            SpaceManagementAuthorization.canManageSpace(
                workspaceRole: "member",
                membershipRole: membershipRole
            ) == false
        )
    }

    @Test func membersWithoutSpaceMembershipCannotManageSpaces() {
        #expect(
            SpaceManagementAuthorization.canManageSpace(
                workspaceRole: "member",
                membershipRole: nil
            ) == false
        )
    }
}
