import Foundation

@MainActor
protocol DocumentKernel: AnyObject, Sendable {
    var documentEngine: any NativeEditorCRDTDocumentEngine { get }
    func validate(_ update: Data) async throws
    func apply(_ update: Data) async throws -> NativeEditorCRDTDocumentSnapshot?
    func snapshot() async throws -> NativeEditorCRDTDocumentSnapshot?
    func encodeState() async throws -> Data
}

@MainActor
final class NativeEditorDocumentKernel: DocumentKernel {
    let documentEngine: any NativeEditorCRDTDocumentEngine

    init(documentEngine: any NativeEditorCRDTDocumentEngine) {
        self.documentEngine = documentEngine
    }

    func validate(_ update: Data) async throws {
        try await documentEngine.validateUpdate(update)
    }

    func apply(_ update: Data) async throws -> NativeEditorCRDTDocumentSnapshot? {
        if let javaScriptEngine = documentEngine as? NativeEditorJSCRDTDocumentEngine {
            return try javaScriptEngine.applyRemoteUpdateAndCaptureSnapshotSynchronously(update)
        }
        return try await documentEngine.applyRemoteUpdateCapturingSnapshot(update)
    }

    func encodeState() async throws -> Data {
        try await documentEngine.encodeDocumentState()
    }

    func snapshot() async throws -> NativeEditorCRDTDocumentSnapshot? {
        try await documentEngine.currentDocumentSnapshot()
    }
}
