import Foundation

nonisolated struct NativeEditorCRDTSaveResult: Equatable, Sendable {
    let title: String?
    let updatedAt: Date?

    init(title: String? = nil, updatedAt: Date? = nil) {
        self.title = title
        self.updatedAt = updatedAt
    }
}

nonisolated struct NativeEditorCRDTDocumentSnapshot: Sendable {
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

protocol NativeEditorCRDTDocumentEngine: AnyObject, Sendable {
    func encodeStateVector() async throws -> Data
    func encodeStateAsUpdate(for stateVector: Data) async throws -> Data
    func applyRemoteUpdate(_ update: Data) async throws
    func integrateLocalChange(_ change: NativeEditorCRDTLocalChange) async throws
    func resolveRemoteCursor(_ cursor: NativeEditorRemoteCursor) async throws -> NativeEditorResolvedRemoteCursor?
    func encodeLocalAwarenessCursor(for selection: NativeEditorLocalTextSelection) async throws
        -> NativeEditorAwarenessCursor?
    func encodeInlineCommentSelection(for selection: NativeEditorLocalTextSelection) async throws
        -> NativeEditorYjsSelection?
    func flushPendingLocalChanges(title: String, document: NativeEditorDocument) async throws
        -> NativeEditorCRDTSaveResult
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
    func integrateLocalChange(_ change: NativeEditorCRDTLocalChange) async throws { }

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
