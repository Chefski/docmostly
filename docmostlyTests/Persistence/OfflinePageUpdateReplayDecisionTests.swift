import Foundation
import Testing
@testable import docmostly

struct OfflinePageUpdateReplayDecisionTests {
    @Test func CRDTReplayOnlyUpdatesAnOfflineTitleWhenRemoteTitleIsUnchanged() {
        #expect(OfflinePageTitleReplayDecision.resolve(
            serverTitle: "Base",
            queuedTitle: "Local",
            baseTitle: "Base"
        ) == .updateTitle)
    }

    @Test func CRDTReplayPreservesAConcurrentRemoteTitleWhenLocalTitleIsUnchanged() {
        #expect(OfflinePageTitleReplayDecision.resolve(
            serverTitle: "Remote",
            queuedTitle: "Base",
            baseTitle: "Base"
        ) == .keepRemoteTitle)
    }

    @Test func CRDTReplayRetainsAConflictForTwoDivergentTitleEdits() {
        #expect(OfflinePageTitleReplayDecision.resolve(
            serverTitle: "Remote",
            queuedTitle: "Local",
            baseTitle: "Base"
        ) == .conflict)
    }

    @Test func matchingLocalBodyNeedsNoDocumentReplacement() {
        let localDocument = document("Local")

        #expect(OfflinePageUpdateReplayDecision.resolve(
            serverPage: page(title: "Local", document: localDocument),
            queuedTitle: "Local",
            queuedDocument: localDocument,
            baseTitle: "Base",
            baseDocument: document("Base")
        ) == .alreadySynchronized)
    }

    @Test func unchangedServerBaselineAllowsReplacement() {
        let baseDocument = document("Base")

        #expect(OfflinePageUpdateReplayDecision.resolve(
            serverPage: page(title: "Base", document: baseDocument),
            queuedTitle: "Local",
            queuedDocument: document("Local"),
            baseTitle: "Base",
            baseDocument: baseDocument
        ) == .replaceDocument(title: "Local"))
    }

    @Test func bodyOnlyEditPreservesNewerRemoteTitle() {
        let baseDocument = document("Base")

        #expect(OfflinePageUpdateReplayDecision.resolve(
            serverPage: page(title: "Remote title", document: baseDocument),
            queuedTitle: "Base title",
            queuedDocument: document("Local body"),
            baseTitle: "Base title",
            baseDocument: baseDocument
        ) == .replaceDocument(title: nil))
    }

    @Test func concurrentDivergentTitleEditsRetainConflict() {
        let baseDocument = document("Base")

        #expect(OfflinePageUpdateReplayDecision.resolve(
            serverPage: page(title: "Remote title", document: baseDocument),
            queuedTitle: "Local title",
            queuedDocument: document("Local body"),
            baseTitle: "Base title",
            baseDocument: baseDocument
        ) == .conflict)
    }

    @Test func unknownOrChangedServerBodyRetainsConflict() {
        #expect(OfflinePageUpdateReplayDecision.resolve(
            serverPage: page(title: "Remote", document: document("Remote")),
            queuedTitle: "Local",
            queuedDocument: document("Local"),
            baseTitle: "Base",
            baseDocument: document("Base")
        ) == .conflict)
        #expect(OfflinePageUpdateReplayDecision.resolve(
            serverPage: page(title: "Remote", document: document("Remote")),
            queuedTitle: "Local",
            queuedDocument: document("Local"),
            baseTitle: nil,
            baseDocument: nil
        ) == .conflict)
    }

    @Test func conflictErrorIsAlwaysRetainedForRetry() {
        #expect(OfflineMutationReplayFailureDisposition(
            error: OfflinePageUpdateReplayConflict(pageID: "page-1")
        ) == .retainForRetry)
    }

    private func document(_ text: String) -> ProseMirrorDocument {
        ProseMirrorDocument(content: [
            ProseMirrorNode(type: "paragraph", content: [ProseMirrorNode(type: "text", text: text)])
        ])
    }

    private func page(title: String, document: ProseMirrorDocument) -> DocmostEditablePage {
        DocmostEditablePage(
            id: "page-1",
            slugId: "page-1",
            title: title,
            content: document,
            icon: nil,
            spaceId: "space-1",
            updatedAt: nil,
            permissions: nil,
            lastUpdatedBy: nil
        )
    }
}
