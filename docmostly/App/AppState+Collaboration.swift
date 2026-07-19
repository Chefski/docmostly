import Foundation

nonisolated struct NativeEditorPreparedDocumentSession: Sendable {
    let session: DocumentSession
    let restoredLocalState: Bool
}

extension AppState {
    func loadCollaborationToken() async throws -> CollaborationTokenResponse {
        guard let apiClient else {
            throw APIError.connectionFailed("Realtime collaboration requires a network connection.")
        }

        return try await apiClient.send(.collabToken)
    }

    func collaborationWebSocketURL() throws -> URL {
        let serverURL = try ServerURLValidator.normalizedURL(from: serverURLString)
        return try NativeEditorCollaborationEndpoint.webSocketURL(serverBaseURL: serverURL)
    }

    func realtimeEventWebSocketURL() throws -> URL {
        let serverURL = try ServerURLValidator.normalizedURL(from: serverURLString)
        return try NativeEditorRealtimeEventEndpoint.webSocketURL(serverBaseURL: serverURL)
    }

    func makeDocumentSession(
        pageID: String,
        title: String,
        document: NativeEditorDocument
    ) async throws -> NativeEditorPreparedDocumentSession? {
        guard let documentSessionRegistry else { return nil }
        guard let cacheScope, let workspaceID = currentUser?.workspace.id else {
            throw APIError.connectionFailed("Offline collaboration storage is unavailable until you sign in.")
        }
        let key = DocumentStoreKey(
            serverBaseURL: cacheScope.serverBaseURL,
            userID: cacheScope.userID,
            workspaceID: workspaceID,
            pageID: pageID
        )
        let session = try await documentSessionRegistry.session(
            for: key,
            title: title,
            document: document
        )
        return NativeEditorPreparedDocumentSession(
            session: session,
            restoredLocalState: session.restoredLocalState
        )
    }

}

enum NativeEditorCRDTDocumentEngineAttachment {
    @MainActor
    static func attachIfAvailable(
        to editorViewModel: NativeRichEditorViewModel,
        appState: AppState
    ) async {
        let pageID = editorViewModel.currentPageID
        let title = editorViewModel.title
        let document = editorViewModel.document

        do {
            try Task.checkCancellation()
            guard let preparedSession = try await appState.makeDocumentSession(
                pageID: pageID,
                title: title,
                document: document
            ) else {
                editorViewModel.markCollaborationUnavailable("Native CRDT runtime is unavailable.")
                return
            }

            try Task.checkCancellation()
            editorViewModel.configureDocumentSession(
                preparedSession.session,
                restoredLocalState: preparedSession.restoredLocalState
            )
            if appState.isOffline, preparedSession.restoredLocalState == false {
                editorViewModel.markCollaborationUnavailable(
                    "Open this page online once before editing it offline so its collaborative state can be cached."
                )
            }
        } catch is CancellationError {
            return
        } catch {
            editorViewModel.markCollaborationUnavailable(error.localizedDescription)
        }
    }
}
