import Foundation
import Testing
@testable import docmostly

struct PageReaderCollaborationTaskKeyTests {
    @Test func collaborationPresenceTaskKeyTracksParticipation() {
        let interactiveKey = PageReaderCollaborationTaskKeys.collaborationPresence(
            pageID: "page-1",
            participation: .interactive
        )
        let receiveOnlyKey = PageReaderCollaborationTaskKeys.collaborationPresence(
            pageID: "page-1",
            participation: .receiveOnly
        )

        #expect(interactiveKey != receiveOnlyKey)
    }

    @Test func collaborationPresenceTaskKeyRequiresAVisiblePage() {
        #expect(
            PageReaderCollaborationTaskKeys.collaborationPresence(
                pageID: "page-1",
                participation: .interactive,
                isVisible: false
            ) == nil
        )
        #expect(
            PageReaderCollaborationTaskKeys.collaborationPresence(
                pageID: "page-1",
                participation: .interactive,
                isVisible: true
            ) != nil
        )
    }

    @Test func realtimeAndCRDTSnapshotTaskKeysStayPageScopedAcrossParticipation() {
        #expect(
            PageReaderCollaborationTaskKeys.realtimeEvents(
                pageID: "page-1",
                participation: .interactive
            ) == PageReaderCollaborationTaskKeys.realtimeEvents(
                pageID: "page-1",
                participation: .receiveOnly
            )
        )
        #expect(
            PageReaderCollaborationTaskKeys.crdtDocumentSnapshots(
                pageID: "page-1",
                participation: .interactive
            ) == PageReaderCollaborationTaskKeys.crdtDocumentSnapshots(
                pageID: "page-1",
                participation: .receiveOnly
            )
        )
    }
}
