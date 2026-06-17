import Foundation

struct NativeEditorCollaborationSession: Sendable {
    let document: NativeEditorCollaborationDocument
    let syncDriver: NativeEditorCollaborationSyncDriver?
    let localAwarenessCursor: (@Sendable () async -> NativeEditorAwarenessCursor?)?

    var documentName: String {
        document.name
    }
}
