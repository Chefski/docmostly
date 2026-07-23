import Foundation

actor NativeEditorCollaborationSyncDriver {
    private let documentName: String
    private let coordinator: NativeEditorCRDTSyncCoordinator
    private var initialPendingUpdates: [Data] = []
    private var awaitingAcknowledgement: [Data] = []
    private var initialLiveUpdateSuppressionCounts: [Data: Int] = [:]

    init(documentName: String, coordinator: NativeEditorCRDTSyncCoordinator) {
        self.documentName = documentName
        self.coordinator = coordinator
    }

    func outboundFramesAfterAuthentication(includePendingLocalUpdates: Bool = true) async throws -> [Data] {
        awaitingAcknowledgement = []
        initialLiveUpdateSuppressionCounts = [:]
        let initialMessage = try await coordinator.makeInitialSyncMessage()
        let initial = frame(for: initialMessage)
        guard includePendingLocalUpdates else {
            initialPendingUpdates = []
            return [initial]
        }
        initialPendingUpdates = try await coordinator.pendingLocalUpdates()
        for update in initialPendingUpdates {
            initialLiveUpdateSuppressionCounts[update, default: 0] += 1
        }
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
        awaitingAcknowledgement.append(contentsOf: updates)
    }

    func outboundFrames(for message: NativeEditorYjsSyncMessage) async throws -> [Data] {
        let outgoingMessages = try await coordinator.receive(message)
        return outgoingMessages.map { frame(for: $0) }
    }

    func outboundFrame(forLocalUpdate update: Data) async -> Data {
        let message = await coordinator.broadcastLocalUpdate(update)
        return frame(for: message)
    }

    func outboundFrameIfNeeded(forLocalUpdate update: Data) async -> Data? {
        if let count = initialLiveUpdateSuppressionCounts[update] {
            if count == 1 {
                initialLiveUpdateSuppressionCounts[update] = nil
            } else {
                initialLiveUpdateSuppressionCounts[update] = count - 1
            }
            return nil
        }
        return await outboundFrame(forLocalUpdate: update)
    }

    func didSendLocalUpdate(_ update: Data) async throws {
        awaitingAcknowledgement.append(update)
    }

    func didReceiveSyncAcknowledgement() async throws {
        while let update = awaitingAcknowledgement.first {
            try await coordinator.recordLocalUpdateAcknowledged(update)
            awaitingAcknowledgement.removeFirst()
        }
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
