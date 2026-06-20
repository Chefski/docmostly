import Testing
@testable import docmostly

struct WorkspaceInvitationDraftTests {
    @Test func parsesCommaAndSpaceSeparatedEmails() {
        var draft = WorkspaceInvitationDraft()
        draft.emailsText = "alice@example.com, bob@example.com carol@example.com"

        #expect(draft.emails == ["alice@example.com", "bob@example.com", "carol@example.com"])
    }

    @Test func validatesEmailCountRoleAndFormat() {
        var draft = WorkspaceInvitationDraft()

        #expect(draft.validationMessage == "Enter at least one email address.")

        draft.emailsText = "not-an-email"
        #expect(draft.validationMessage == "Every invitation needs a valid email address.")

        draft.emailsText = "alice@example.com"
        draft.role = "owner"
        #expect(draft.validationMessage == "Invitations can assign admin or member roles.")

        draft.role = "member"
        #expect(draft.validationMessage == nil)
    }
}
