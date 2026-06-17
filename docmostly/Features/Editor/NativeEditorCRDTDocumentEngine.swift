import Foundation

protocol NativeEditorCRDTDocumentEngine: AnyObject, Sendable {
    func encodeStateVector() async throws -> Data
    func encodeStateAsUpdate(for stateVector: Data) async throws -> Data
    func applyRemoteUpdate(_ update: Data) async throws
    func resolveRemoteCursor(_ cursor: NativeEditorRemoteCursor) async throws -> NativeEditorResolvedRemoteCursor?
}

extension NativeEditorCRDTDocumentEngine {
    func resolveRemoteCursor(_ cursor: NativeEditorRemoteCursor) async throws -> NativeEditorResolvedRemoteCursor? {
        nil
    }
}
