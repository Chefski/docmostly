import Foundation

actor NativeEditorCRDTSyncCoordinator {
    private let documentEngine: any NativeEditorCRDTDocumentEngine
    private var pendingLocalEchoCounts: [Data: Int] = [:]

    init(documentEngine: any NativeEditorCRDTDocumentEngine) {
        self.documentEngine = documentEngine
    }

    func makeInitialSyncMessage() async throws -> NativeEditorYjsSyncMessage {
        .stepOne(try await documentEngine.encodeStateVector())
    }

    func receive(_ message: NativeEditorYjsSyncMessage) async throws -> [NativeEditorYjsSyncMessage] {
        switch message {
        case .stepOne(let stateVector):
            return [.stepTwo(try await documentEngine.encodeStateAsUpdate(for: stateVector))]
        case .stepTwo(let update), .update(let update):
            guard consumeLocalEcho(for: update) == false else { return [] }
            try await documentEngine.applyRemoteUpdate(update)
            return []
        }
    }

    func broadcastLocalUpdate(_ update: Data) -> NativeEditorYjsSyncMessage {
        pendingLocalEchoCounts[update, default: 0] += 1
        return .update(update)
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
}
