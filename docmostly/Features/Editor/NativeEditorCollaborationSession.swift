import Foundation

struct NativeEditorCollaborationSession: Sendable {
    let document: NativeEditorCollaborationDocument
    let syncDriver: NativeEditorCollaborationSyncDriver?
    let localAwarenessCursor: (@Sendable () async -> NativeEditorAwarenessCursor?)?
    let localAwarenessUpdates: AsyncStream<Void>?

    var documentName: String {
        document.name
    }
}
