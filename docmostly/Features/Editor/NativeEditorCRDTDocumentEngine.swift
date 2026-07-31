import Foundation

nonisolated struct NativeEditorCRDTSaveResult: Equatable, Sendable {
    let title: String?
    let updatedAt: Date?
    let documentStateUpdate: Data?

    init(title: String? = nil, updatedAt: Date? = nil, documentStateUpdate: Data? = nil) {
        self.title = title
        self.updatedAt = updatedAt
        self.documentStateUpdate = documentStateUpdate
    }
}

nonisolated struct NativeEditorCRDTDocumentSnapshot: Equatable, Sendable {
    let title: String?
    let document: NativeEditorDocument
    let updatedAt: Date?

    init(title: String? = nil, document: NativeEditorDocument, updatedAt: Date? = nil) {
        self.title = title
        self.document = document
        self.updatedAt = updatedAt
    }
}

nonisolated struct NativeEditorCRDTLocalChange: Sendable {
    let before: NativeEditorHistorySnapshot
    let after: NativeEditorHistorySnapshot
}

nonisolated struct NativeEditorCRDTCommittedSave: Sendable {
    let result: NativeEditorCRDTSaveResult
    let updates: [Data]
}

protocol NativeEditorCRDTDocumentEngine: AnyObject, Sendable {
    var requiresInitialRemoteSnapshot: Bool { get }
    func encodeStateVector() async throws -> Data
    func encodeStateAsUpdate(for stateVector: Data) async throws -> Data
    func encodeDocumentState() async throws -> Data
    func validateUpdate(_ update: Data) async throws
    func applyRemoteUpdate(_ update: Data) async throws
    func applyRemoteUpdateCapturingSnapshot(_ update: Data) async throws -> NativeEditorCRDTDocumentSnapshot?
    func currentDocumentSnapshot() async throws -> NativeEditorCRDTDocumentSnapshot?
    func integrateLocalChange(_ change: NativeEditorCRDTLocalChange) async throws
    func integrateLocalChangeForCommit(_ change: NativeEditorCRDTLocalChange) async throws -> [Data]
    func resolveRemoteCursor(_ cursor: NativeEditorRemoteCursor) async throws -> NativeEditorResolvedRemoteCursor?
    func encodeLocalAwarenessCursor(for selection: NativeEditorLocalTextSelection) async throws
        -> NativeEditorAwarenessCursor?
    func encodeInlineCommentSelection(for selection: NativeEditorLocalTextSelection) async throws
        -> NativeEditorYjsSelection?
    func flushPendingLocalChanges(title: String, document: NativeEditorDocument) async throws
        -> NativeEditorCRDTSaveResult
    func flushPendingLocalChangesForCommit(title: String, document: NativeEditorDocument) async throws
        -> NativeEditorCRDTCommittedSave
    func localUpdates() async -> AsyncStream<Data>
    func documentSnapshots() async -> AsyncStream<NativeEditorCRDTDocumentSnapshot>
}

@MainActor
protocol NativeEditorCRDTDocumentEngineFactory: AnyObject {
    func makeDocumentEngine(
        pageID: String,
        title: String,
        document: NativeEditorDocument
    ) async throws -> any NativeEditorCRDTDocumentEngine
}

extension NativeEditorCRDTDocumentEngine {
    var requiresInitialRemoteSnapshot: Bool {
        false
    }

    func applyRemoteUpdateCapturingSnapshot(_ update: Data) async throws -> NativeEditorCRDTDocumentSnapshot? {
        try await applyRemoteUpdate(update)
        return nil
    }

    func currentDocumentSnapshot() async throws -> NativeEditorCRDTDocumentSnapshot? {
        nil
    }

    func validateUpdate(_ update: Data) async throws {
        guard update.isEmpty == false else {
            throw NativeEditorJSCRDTEngineError.invalidDataResult("validateUpdate")
        }
    }

    func encodeDocumentState() async throws -> Data {
        // Yjs update-v1 encodes an empty state vector as a single zero byte.
        try await encodeStateAsUpdate(for: Data([0]))
    }

    func integrateLocalChange(_ change: NativeEditorCRDTLocalChange) async throws { }

    func integrateLocalChangeForCommit(_ change: NativeEditorCRDTLocalChange) async throws -> [Data] {
        try await integrateLocalChange(change)
        return []
    }

    func flushPendingLocalChangesForCommit(
        title: String,
        document: NativeEditorDocument
    ) async throws -> NativeEditorCRDTCommittedSave {
        NativeEditorCRDTCommittedSave(
            result: try await flushPendingLocalChanges(title: title, document: document),
            updates: []
        )
    }

    func resolveRemoteCursor(_ cursor: NativeEditorRemoteCursor) async throws -> NativeEditorResolvedRemoteCursor? {
        nil
    }

    func encodeLocalAwarenessCursor(for selection: NativeEditorLocalTextSelection) async throws
        -> NativeEditorAwarenessCursor? {
        nil
    }

    func encodeInlineCommentSelection(for selection: NativeEditorLocalTextSelection) async throws
        -> NativeEditorYjsSelection? {
        nil
    }

    func localUpdates() async -> AsyncStream<Data> {
        let (stream, continuation) = AsyncStream.makeStream(of: Data.self)
        continuation.finish()
        return stream
    }

    func documentSnapshots() async -> AsyncStream<NativeEditorCRDTDocumentSnapshot> {
        let (stream, continuation) = AsyncStream.makeStream(of: NativeEditorCRDTDocumentSnapshot.self)
        continuation.finish()
        return stream
    }
}
