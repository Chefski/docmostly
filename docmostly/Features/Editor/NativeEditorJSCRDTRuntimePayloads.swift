import Foundation

struct NativeEditorJSCRDTRuntimeSaveResult: Decodable {
    let title: String?
    let updatedAt: String?
}

struct NativeEditorJSCRDTRuntimeSnapshot: Decodable {
    let title: String?
    let document: ProseMirrorDocument
    let updatedAt: String?

    func crdtSnapshot() throws -> NativeEditorCRDTDocumentSnapshot {
        NativeEditorCRDTDocumentSnapshot(
            title: title,
            document: NativeEditorDocument(proseMirrorDocument: document),
            updatedAt: try NativeEditorJSCRDTDateParser.date(from: updatedAt)
        )
    }
}

enum NativeEditorJSCRDTDateParser {
    static func date(from value: String?) throws -> Date? {
        guard let value else { return nil }

        do {
            return try Date(value, strategy: .iso8601)
        } catch {
            throw NativeEditorJSCRDTEngineError.invalidDate(value)
        }
    }
}
