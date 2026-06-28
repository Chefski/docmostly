import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorCollabStatusTests {
    @Test func failedAuthStatusTakesPriorityOverReadOnlyEditingState() {
        let presentation = NativeEditorCollabStatusPresentation(
            realtimeStatus: .authenticationFailed("Invalid collab token"),
            canEdit: false,
            activeCollaborators: [],
            pendingRemoteUpdate: nil
        )

        #expect(presentation.title == "Failed auth")
    }

    @Test func failedAuthIconTakesPriorityOverReadOnlyEditingState() {
        let presentation = NativeEditorCollabStatusPresentation(
            realtimeStatus: .authenticationFailed("Invalid collab token"),
            canEdit: false,
            activeCollaborators: [],
            pendingRemoteUpdate: nil
        )

        #expect(presentation.imageName == "person.crop.circle.badge.exclamationmark")
    }

    @Test func reconnectingStatusUsesExplicitCopy() {
        let presentation = NativeEditorCollabStatusPresentation(
            realtimeStatus: .connecting,
            canEdit: true,
            activeCollaborators: [],
            pendingRemoteUpdate: nil
        )

        #expect(presentation.title == "Reconnecting")
    }

    @Test func failureStatusTakesPriorityOverPresenceCopy() {
        let presentation = NativeEditorCollabStatusPresentation(
            realtimeStatus: .failed("Native CRDT runtime is unavailable."),
            canEdit: false,
            activeCollaborators: [
                NativeEditorCollaborator(id: "user-2", name: "Alice", colorName: "#2563EB")
            ],
            pendingRemoteUpdate: nil
        )

        #expect(presentation.title == "Sync failed")
    }
}
