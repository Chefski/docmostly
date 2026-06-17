import Foundation

nonisolated struct NativeEditorCollabAuthFailure: Equatable, LocalizedError, Sendable {
    let reason: String

    var errorDescription: String? {
        reason.isEmpty ? "Realtime collaboration authentication failed." : reason
    }
}

nonisolated struct NativeEditorCollabAuthRetry: Equatable, Sendable {
    private var didRetryAuthenticationFailure = false

    mutating func shouldRetryImmediately(after error: any Error) -> Bool {
        guard error is NativeEditorCollabAuthFailure else { return false }
        guard didRetryAuthenticationFailure == false else { return false }

        didRetryAuthenticationFailure = true
        return true
    }

    mutating func markAuthenticated() {
        didRetryAuthenticationFailure = false
    }
}
