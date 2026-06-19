import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorCollabStatusTests {
    @Test func unsupportedSyncStatusTakesPriorityOverReadOnlyEditingState() {
        let presentation = NativeEditorCollabStatusPresentation(
            realtimeStatus: .unsupported("Unsupported collaboration permission scope."),
            canEdit: false,
            activeCollaborators: [],
            pendingRemoteUpdate: nil
        )

        #expect(presentation.title == "Limited live sync")
    }

    @Test func unsupportedSyncIconTakesPriorityOverReadOnlyEditingState() {
        let presentation = NativeEditorCollabStatusPresentation(
            realtimeStatus: .unsupported("Unsupported collaboration permission scope."),
            canEdit: false,
            activeCollaborators: [],
            pendingRemoteUpdate: nil
        )

        #expect(presentation.imageName == "point.3.connected.trianglepath.dotted")
    }
}
