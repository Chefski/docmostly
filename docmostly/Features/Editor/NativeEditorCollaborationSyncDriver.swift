import Foundation

actor NativeEditorCollaborationSyncDriver {
    private let documentName: String
    private let coordinator: NativeEditorCRDTSyncCoordinator
    private var initialPendingUpdates: [Data] = []

    init(documentName: String, coordinator: NativeEditorCRDTSyncCoordinator) {
        self.documentName = documentName
        self.coordinator = coordinator
    }

    func outboundFramesAfterAuthentication() async throws -> [Data] {
        let initialMessage = try await coordinator.makeInitialSyncMessage()
        let initial = frame(for: initialMessage)
        initialPendingUpdates = try await coordinator.pendingLocalUpdates()
        var pending: [Data] = []
        pending.reserveCapacity(initialPendingUpdates.count)
        for update in initialPendingUpdates {
            let message = await coordinator.broadcastLocalUpdate(update)
            pending.append(frame(for: message))
        }
        return [initial] + pending
    }

    func didSendOutboundFramesAfterAuthentication() async throws {
        let updates = initialPendingUpdates
        initialPendingUpdates = []
        for update in updates {
            try await coordinator.recordLocalUpdateSent(update)
        }
    }

    func outboundFrames(for message: NativeEditorYjsSyncMessage) async throws -> [Data] {
        let outgoingMessages = try await coordinator.receive(message)
        return outgoingMessages.map { frame(for: $0) }
    }

    func outboundFrame(forLocalUpdate update: Data) async -> Data {
        let message = await coordinator.broadcastLocalUpdate(update)
        return frame(for: message)
    }

    func didSendLocalUpdate(_ update: Data) async throws {
        try await coordinator.recordLocalUpdateSent(update)
    }

    func localUpdates() async -> AsyncStream<Data> {
        await coordinator.localUpdates()
    }

    func localAwarenessCursor(
        for selection: NativeEditorLocalTextSelection
    ) async throws -> NativeEditorAwarenessCursor? {
        try await coordinator.encodeLocalAwarenessCursor(for: selection)
    }

    private func frame(for message: NativeEditorYjsSyncMessage) -> Data {
        NativeEditorHocuspocusFrame.sync(documentName: documentName, message: message)
    }
}
