import Foundation

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

    func makeCRDTDocumentEngine(
        pageID: String,
        title: String,
        document: NativeEditorDocument
    ) async throws -> (any NativeEditorCRDTDocumentEngine)? {
        guard let crdtDocumentEngineFactory else { return nil }

        return try await crdtDocumentEngineFactory.makeDocumentEngine(
            pageID: pageID,
            title: title,
            document: document
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
            guard let engine = try await appState.makeCRDTDocumentEngine(
                pageID: pageID,
                title: title,
                document: document
            ) else {
                return
            }

            editorViewModel.configureCRDTDocumentEngine(engine)
        } catch {
            editorViewModel.realtimeStatus = .unsupported(error.localizedDescription)
        }
    }
}
