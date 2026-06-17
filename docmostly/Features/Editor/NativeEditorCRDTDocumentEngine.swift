import Foundation

protocol NativeEditorCRDTDocumentEngine: AnyObject, Sendable {
    func encodeStateVector() async throws -> Data
    func encodeStateAsUpdate(for stateVector: Data) async throws -> Data
    func applyRemoteUpdate(_ update: Data) async throws
    func resolveRemoteCursor(_ cursor: NativeEditorRemoteCursor) async throws -> NativeEditorResolvedRemoteCursor?
    func encodeLocalAwarenessCursor(for selection: NativeEditorLocalTextSelection) async throws
        -> NativeEditorAwarenessCursor?
}

extension NativeEditorCRDTDocumentEngine {
    func resolveRemoteCursor(_ cursor: NativeEditorRemoteCursor) async throws -> NativeEditorResolvedRemoteCursor? {
        nil
    }

    func encodeLocalAwarenessCursor(for selection: NativeEditorLocalTextSelection) async throws
        -> NativeEditorAwarenessCursor? {
        nil
    }
}
