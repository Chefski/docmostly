import Foundation

nonisolated enum NativeEditorOfflineCRDTSyncError: LocalizedError, Equatable, Sendable {
    case writeAccessRequired
    case timedOut
    case disconnectedBeforeSync

    var errorDescription: String? {
        switch self {
        case .writeAccessRequired:
            "The queued collaborative edit no longer has permission to update this page."
        case .timedOut:
            "The queued collaborative edit did not finish syncing in time."
        case .disconnectedBeforeSync:
            "The collaboration server disconnected before the queued edit was synchronized."
        }
    }
}

protocol NativeEditorOfflineCRDTSynchronizing: Sendable {
    func synchronize(
        pageID: String,
        session: DocumentSession,
        url: URL,
        token: String,
        user: DocmostUser?
    ) async throws
}

actor NativeEditorOfflineCRDTSynchronizer: NativeEditorOfflineCRDTSynchronizing {
    private let urlSession: URLSession
    private let timeout: Duration

    init(urlSession: URLSession = .shared, timeout: Duration = .seconds(30)) {
        self.urlSession = urlSession
        self.timeout = timeout
    }

    func synchronize(
        pageID: String,
        session: DocumentSession,
        url: URL,
        token: String,
        user: DocmostUser?
    ) async throws {
        guard try await session.hasPendingSynchronization() else { return }
        guard let coordinator = await session.syncCoordinator else {
            throw APIError.connectionFailed("The local document session could not start collaboration.")
        }

        let client = NativeEditorCollaborationPresenceClient(urlSession: urlSession)
        let document = NativeEditorCollaborationDocument(pageID: pageID)
        let syncDriver = NativeEditorCollaborationSyncDriver(
            documentName: document.name,
            coordinator: coordinator
        )
        let events = await client.events(
            url: url,
            token: token,
            documentName: document.name,
            participation: .interactive,
            user: user,
            syncDriver: syncDriver
        )

        do {
            try await waitForSynchronization(events: events, session: session)
            await client.disconnect()
        } catch {
            await client.disconnect()
            throw error
        }
    }

    private func waitForSynchronization(
        events: AsyncThrowingStream<NativeEditorCollaborationEvent, any Error>,
        session: DocumentSession
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                var hasWriteAccess = false
                for try await event in events {
                    switch event {
                    case .authenticated(let scope):
                        guard scope.allowsLocalDocumentUpdates else {
                            throw NativeEditorOfflineCRDTSyncError.writeAccessRequired
                        }
                        hasWriteAccess = true
                    case .syncStatus(true) where hasWriteAccess:
                        if try await session.hasPendingSynchronization() == false {
                            return
                        }
                    case .awareness, .stateless, .syncStatus:
                        continue
                    }
                }
                throw NativeEditorOfflineCRDTSyncError.disconnectedBeforeSync
            }
            group.addTask { [timeout] in
                try await Task.sleep(for: timeout)
                throw NativeEditorOfflineCRDTSyncError.timedOut
            }

            defer { group.cancelAll() }
            _ = try await group.next()
        }
    }
}
