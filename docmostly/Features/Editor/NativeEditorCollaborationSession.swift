import Foundation

struct NativeEditorCollaborationSession: Sendable {
    let documentName: String
    let syncDriver: NativeEditorCollaborationSyncDriver?
}
