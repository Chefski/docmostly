import Foundation

nonisolated struct NativeEditorPreparedCRDTDocumentEngine: Sendable {
    let engine: any NativeEditorCRDTDocumentEngine
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

    func makeCRDTDocumentEngine(
        pageID: String,
        title: String,
        document: NativeEditorDocument
    ) async throws -> NativeEditorPreparedCRDTDocumentEngine? {
        guard let crdtDocumentEngineFactory else { return nil }

        let engine = try await crdtDocumentEngineFactory.makeDocumentEngine(
            pageID: pageID,
            title: title,
            document: document
        )
        let restoredState = try await loadCachedCRDTStateUpdate(pageID: pageID)
        if let restoredState {
            try await engine.applyRemoteUpdate(restoredState)
        }
        return NativeEditorPreparedCRDTDocumentEngine(
            engine: engine,
            restoredLocalState: restoredState != nil
        )
    }

    func persistCRDTStateUpdate(pageID: String, update: Data) async throws {
        guard update.isEmpty == false else {
            throw APIError.connectionFailed("The collaborative document returned an empty local state.")
        }
        let scope = try requireCacheScope(
            message: "Offline collaboration storage is unavailable until you sign in."
        )
        if let cacheWriter {
            try await cacheWriter.saveCRDTStateUpdate(pageId: pageID, update: update, scope: scope)
            return
        }
        guard let cacheRepository else {
            throw APIError.connectionFailed("Offline collaboration storage is unavailable on this device.")
        }
        try cacheRepository.saveCRDTStateUpdate(pageId: pageID, update: update, scope: scope)
    }

    private func loadCachedCRDTStateUpdate(pageID: String) async throws -> Data? {
        guard let cacheScope else { return nil }
        if let cacheReader {
            return try await cacheReader.loadCRDTStateUpdate(pageId: pageID, scope: cacheScope)
        }
        return try cacheRepository?.loadCRDTStateUpdate(pageId: pageID, scope: cacheScope)
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
            guard let preparedEngine = try await appState.makeCRDTDocumentEngine(
                pageID: pageID,
                title: title,
                document: document
            ) else {
                editorViewModel.markCollaborationUnavailable("Native CRDT runtime is unavailable.")
                return
            }

            try Task.checkCancellation()
            editorViewModel.configureCRDTDocumentEngine(
                preparedEngine.engine,
                restoredLocalState: preparedEngine.restoredLocalState
            )
            if appState.isOffline, preparedEngine.restoredLocalState == false {
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
