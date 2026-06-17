import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorCollaborationAuthRetryTests {
    @Test func retriesCollaborationAuthenticationFailureOnceUntilAuthenticated() {
        var retry = NativeEditorCollabAuthRetry()
        let firstRetry = retry.shouldRetryImmediately(
            after: NativeEditorCollabAuthFailure(reason: "token expired")
        )
        let secondRetry = retry.shouldRetryImmediately(
            after: NativeEditorCollabAuthFailure(reason: "token expired")
        )

        #expect(firstRetry)
        #expect(secondRetry == false)

        let genericRetry = retry.shouldRetryImmediately(after: APIError.connectionFailed("offline"))
        #expect(genericRetry == false)

        retry.markAuthenticated()

        let retryAfterAuthentication = retry.shouldRetryImmediately(
            after: NativeEditorCollabAuthFailure(reason: "token expired")
        )
        #expect(retryAfterAuthentication)
    }

    @Test func collaborationAuthenticationFailureDescribesServerReason() {
        #expect(
            NativeEditorCollabAuthFailure(reason: "token expired").localizedDescription ==
                "token expired"
        )
        #expect(
            NativeEditorCollabAuthFailure(reason: "").localizedDescription ==
                "Realtime collaboration authentication failed."
        )
    }
}
