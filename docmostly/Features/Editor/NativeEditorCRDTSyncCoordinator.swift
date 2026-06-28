import Foundation

nonisolated enum NativeEditorCRDTSyncCoordinatorError: Error, Equatable, Sendable {
    case remotePayloadTooLarge
}

actor NativeEditorCRDTSyncCoordinator {
    nonisolated static let maximumRemoteSyncPayloadBytes = NativeEditorLib0Decoder.maximumDecodedPayloadBytes
    nonisolated static let maximumRemoteSyncSessionBytes = 10_000_000

    private let documentEngine: any NativeEditorCRDTDocumentEngine
    private var pendingLocalEchoCounts: [Data: Int] = [:]
    private var remoteSyncSessionBytes = 0

    init(documentEngine: any NativeEditorCRDTDocumentEngine) {
        self.documentEngine = documentEngine
    }

    func makeInitialSyncMessage() async throws -> NativeEditorYjsSyncMessage {
        .stepOne(try await documentEngine.encodeStateVector())
    }

    func receive(_ message: NativeEditorYjsSyncMessage) async throws -> [NativeEditorYjsSyncMessage] {
        switch message {
        case .stepOne(let stateVector):
            try validateRemotePayload(stateVector)
            try recordRemotePayload(stateVector)
            return [.stepTwo(try await documentEngine.encodeStateAsUpdate(for: stateVector))]
        case .stepTwo(let update), .update(let update):
            try validateRemotePayload(update)
            try recordRemotePayload(update)
            guard consumeLocalEcho(for: update) == false else { return [] }
            try await documentEngine.applyRemoteUpdate(update)
            return []
        }
    }

    func broadcastLocalUpdate(_ update: Data) -> NativeEditorYjsSyncMessage {
        pendingLocalEchoCounts[update, default: 0] += 1
        return .update(update)
    }

    func encodeLocalAwarenessCursor(for selection: NativeEditorLocalTextSelection) async throws
        -> NativeEditorAwarenessCursor? {
        try await documentEngine.encodeLocalAwarenessCursor(for: selection)
    }

    func localUpdates() async -> AsyncStream<Data> {
        await documentEngine.localUpdates()
    }

    private func consumeLocalEcho(for update: Data) -> Bool {
        guard let count = pendingLocalEchoCounts[update] else { return false }

        if count == 1 {
            pendingLocalEchoCounts[update] = nil
        } else {
            pendingLocalEchoCounts[update] = count - 1
        }

        return true
    }

    private func validateRemotePayload(_ data: Data) throws {
        guard data.count <= Self.maximumRemoteSyncPayloadBytes else {
            throw NativeEditorCRDTSyncCoordinatorError.remotePayloadTooLarge
        }
    }

    private func recordRemotePayload(_ data: Data) throws {
        remoteSyncSessionBytes += data.count
        guard remoteSyncSessionBytes <= Self.maximumRemoteSyncSessionBytes else {
            throw NativeEditorCRDTSyncCoordinatorError.remotePayloadTooLarge
        }
    }
}
