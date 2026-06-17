import Foundation

actor NativeEditorCollaborationSyncDriver {
    private let documentName: String
    private let coordinator: NativeEditorCRDTSyncCoordinator

    init(documentName: String, coordinator: NativeEditorCRDTSyncCoordinator) {
        self.documentName = documentName
        self.coordinator = coordinator
    }

    func outboundFramesAfterAuthentication() async throws -> [Data] {
        [try await frame(for: coordinator.makeInitialSyncMessage())]
    }

    func outboundFrames(for message: NativeEditorYjsSyncMessage) async throws -> [Data] {
        let outgoingMessages = try await coordinator.receive(message)
        return outgoingMessages.map { frame(for: $0) }
    }

    func outboundFrame(forLocalUpdate update: Data) async -> Data {
        let message = await coordinator.broadcastLocalUpdate(update)
        return frame(for: message)
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
