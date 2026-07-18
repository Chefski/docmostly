import Foundation
import Testing
@testable import docmostly

struct OfflinePageUpdateReplayDecisionTests {
    @Test func matchingLocalBodyNeedsNoDocumentReplacement() {
        let localDocument = document("Local")

        #expect(OfflinePageUpdateReplayDecision.resolve(
            serverPage: page(title: "Local", document: localDocument),
            queuedTitle: "Local",
            queuedDocument: localDocument,
            baseDocument: document("Base")
        ) == .alreadySynchronized)
    }

    @Test func unchangedServerBaselineAllowsReplacement() {
        let baseDocument = document("Base")

        #expect(OfflinePageUpdateReplayDecision.resolve(
            serverPage: page(title: "Base", document: baseDocument),
            queuedTitle: "Local",
            queuedDocument: document("Local"),
            baseDocument: baseDocument
        ) == .replaceDocument)
    }

    @Test func unknownOrChangedServerBodyRetainsConflict() {
        #expect(OfflinePageUpdateReplayDecision.resolve(
            serverPage: page(title: "Remote", document: document("Remote")),
            queuedTitle: "Local",
            queuedDocument: document("Local"),
            baseDocument: document("Base")
        ) == .conflict)
        #expect(OfflinePageUpdateReplayDecision.resolve(
            serverPage: page(title: "Remote", document: document("Remote")),
            queuedTitle: "Local",
            queuedDocument: document("Local"),
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
