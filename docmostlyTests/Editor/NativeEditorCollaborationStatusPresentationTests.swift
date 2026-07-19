import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorCollabStatusTests {
    @Test func failedAuthStatusTakesPriorityOverReadOnlyEditingState() {
        let presentation = NativeEditorCollabStatusPresentation(
            realtimeStatus: .authenticationFailed("Invalid collab token"),
            canEdit: false,
            pendingRemoteUpdate: nil
        )

        #expect(presentation.title == "Failed auth")
    }

    @Test func failedAuthIconTakesPriorityOverReadOnlyEditingState() {
        let presentation = NativeEditorCollabStatusPresentation(
            realtimeStatus: .authenticationFailed("Invalid collab token"),
            canEdit: false,
            pendingRemoteUpdate: nil
        )

        #expect(presentation.imageName == "person.crop.circle.badge.exclamationmark")
    }

    @Test func reconnectingStatusStaysHidden() {
        let presentation = NativeEditorCollabStatusPresentation(
            realtimeStatus: .connecting,
            canEdit: true,
            pendingRemoteUpdate: nil
        )

        #expect(presentation.isVisible == false)
    }

    @Test func failureStatusUsesExplicitCopy() {
        let presentation = NativeEditorCollabStatusPresentation(
            realtimeStatus: .failed("Native CRDT runtime is unavailable."),
            canEdit: false,
            pendingRemoteUpdate: nil
        )

        #expect(presentation.title == "Sync failed")
    }

    @Test func connectedEditableStatusStaysHidden() {
        let presentation = NativeEditorCollabStatusPresentation(
            realtimeStatus: .connected,
            canEdit: true,
            pendingRemoteUpdate: nil
        )

        #expect(presentation.isVisible == false)
    }
}
