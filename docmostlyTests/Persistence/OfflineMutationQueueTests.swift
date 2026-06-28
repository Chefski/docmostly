import Foundation
import SwiftData
import Testing
@testable import docmostly

@MainActor
struct OfflineMutationQueueTests {
    private let scope = CacheScope(serverBaseURL: "https://docs.example.com", userID: "user-1")

    @Test func queuedMutationsPersistInWorkspaceAndUserScope() throws {
        let queue = makeQueue()
        let document = ProseMirrorDocument(content: [
            ProseMirrorNode(type: "paragraph", content: [
                ProseMirrorNode(type: "text", text: "Offline draft")
            ])
        ])

        let record = try queue.enqueue(
            .updatePage(pageId: "page-1", title: "Draft", document: document),
            scope: scope
        )

        let pending = try queue.pending(scope: scope)
        #expect(pending.map(\.id) == [record.id])
        #expect(pending.first?.payload == .updatePage(pageId: "page-1", title: "Draft", document: document))
        #expect(try queue.pending(
            scope: CacheScope(serverBaseURL: "https://docs.example.com", userID: "user-2")
        ).isEmpty)
        #expect(try queue.pending(
            scope: CacheScope(serverBaseURL: "https://other.example.com", userID: "user-1")
        ).isEmpty)
    }

    @Test func pageEditsCoalesceToTheLatestDraft() throws {
        let queue = makeQueue()
        let firstDocument = ProseMirrorDocument(content: [
            ProseMirrorNode(type: "paragraph", content: [
                ProseMirrorNode(type: "text", text: "First")
            ])
        ])
        let latestDocument = ProseMirrorDocument(content: [
            ProseMirrorNode(type: "paragraph", content: [
                ProseMirrorNode(type: "text", text: "Latest")
            ])
        ])

        _ = try queue.enqueue(
            .updatePage(pageId: "page-1", title: "First title", document: firstDocument),
            scope: scope
        )
        _ = try queue.enqueue(
            .updatePage(pageId: "page-1", title: "Latest title", document: latestDocument),
            scope: scope
        )

        let pending = try queue.pending(scope: scope)
        #expect(pending.count == 1)
        #expect(pending.first?.payload == .updatePage(
            pageId: "page-1",
            title: "Latest title",
            document: latestDocument
        ))
    }

    @Test func engagementTogglesCoalesceByTarget() throws {
        let queue = makeQueue()

        _ = try queue.enqueue(
            .addFavorite(type: .page, pageId: "page-1", spaceId: nil, templateId: nil),
            scope: scope
        )
        _ = try queue.enqueue(
            .removeFavorite(type: .page, pageId: "page-1", spaceId: nil, templateId: nil),
            scope: scope
        )
        _ = try queue.enqueue(.watchPage(pageId: "page-1"), scope: scope)
        _ = try queue.enqueue(.unwatchPage(pageId: "page-1"), scope: scope)
        _ = try queue.enqueue(.watchSpace(spaceId: "space-1"), scope: scope)

        let pending = try queue.pending(scope: scope)
        #expect(pending.map(\.payload) == [
            .removeFavorite(type: .page, pageId: "page-1", spaceId: nil, templateId: nil),
            .unwatchPage(pageId: "page-1"),
            .watchSpace(spaceId: "space-1")
        ])
    }

    @Test func commentsLabelsAndMovesKeepReplayOrder() throws {
        let queue = makeQueue()
        let first = try queue.enqueue(
            .createComment(
                localId: "offline-comment-1",
                pageId: "page-1",
                content: #"{"type":"doc","content":[]}"#,
                plainText: "Offline comment",
                type: .page,
                selection: nil,
                yjsSelection: nil
            ),
            scope: scope
        )
        let second = try queue.enqueue(
            .addPageLabels(pageId: "page-1", labels: [
                OfflinePageLabel(pageId: "page-1", name: "ios"),
                OfflinePageLabel(pageId: "page-1", name: "offline")
            ]),
            scope: scope
        )
        let third = try queue.enqueue(
            .movePage(pageId: "page-1", parentPageId: "parent-1", position: "a000001"),
            scope: scope
        )

        #expect(try queue.pending(scope: scope).map(\.id) == [first.id, second.id, third.id])
    }

    @Test func legacyQueuedCommentPayloadDecodesWithLocalProjectionFields() throws {
        let payloadData = Data(
            #"""
            {
                "createComment": {
                    "pageId": "page-1",
                    "content": "{\"type\":\"doc\",\"content\":[]}",
                    "type": "inline",
                    "selection": "anchor",
                    "yjsSelection": null
                }
            }
            """#.utf8
        )

        let payload = try JSONDecoder().decode(OfflineMutationPayload.self, from: payloadData)

        guard case .createComment(
            let localId,
            let pageId,
            let content,
            let plainText,
            let type,
            let selection,
            let yjsSelection
        ) = payload else {
            Issue.record("Expected a legacy queued comment payload")
            return
        }
        #expect(localId.hasPrefix("offline-comment-legacy-"))
        #expect(pageId == "page-1")
        #expect(content == #"{"type":"doc","content":[]}"#)
        #expect(plainText == content)
        #expect(type == .inline)
        #expect(selection == "anchor")
        #expect(yjsSelection == nil)
    }

    @Test func legacyQueuedLabelPayloadDecodesNamesAsLocalLabels() throws {
        let payloadData = Data(
            #"""
            {
                "addPageLabels": {
                    "pageId": "page-1",
                    "names": ["ios", "offline"]
                }
            }
            """#.utf8
        )

        let payload = try JSONDecoder().decode(OfflineMutationPayload.self, from: payloadData)

        #expect(payload == .addPageLabels(pageId: "page-1", labels: [
            OfflinePageLabel(pageId: "page-1", name: "ios"),
            OfflinePageLabel(pageId: "page-1", name: "offline")
        ]))
    }

    @Test func removingPendingOfflineLabelCollapsesQueuedAdd() throws {
        let queue = makeQueue()
        let removedLabel = OfflinePageLabel(pageId: "page-1", name: "ios")
        let retainedLabel = OfflinePageLabel(pageId: "page-1", name: "offline")
        _ = try queue.enqueue(
            .addPageLabels(pageId: "page-1", labels: [removedLabel, retainedLabel]),
            scope: scope
        )

        try queue.removePendingPageLabel(pageId: "page-1", localId: removedLabel.id, scope: scope)

        let pending = try queue.pending(scope: scope)
        #expect(pending.map(\.payload) == [
            .addPageLabels(pageId: "page-1", labels: [retainedLabel])
        ])

        try queue.removePendingPageLabel(pageId: "page-1", localId: retainedLabel.id, scope: scope)
        #expect(try queue.pending(scope: scope).isEmpty)
    }

    @Test func replacingQueuedInlineCommentIDPatchesPendingPageUpdates() throws {
        let queue = makeQueue()
        let document = ProseMirrorDocument(content: [
            ProseMirrorNode(type: "paragraph", content: [
                ProseMirrorNode(
                    type: "text",
                    marks: [
                        ProseMirrorMark(
                            type: "comment",
                            attrs: ["commentId": .string("offline-comment-1"), "resolved": .bool(false)]
                        )
                    ],
                    text: "Marked"
                )
            ])
        ])

        _ = try queue.enqueue(
            .updatePage(pageId: "page-1", title: "Draft", document: document),
            scope: scope
        )

        try queue.replaceQueuedInlineCommentID(
            localId: "offline-comment-1",
            serverId: "comment-1",
            scope: scope
        )

        let pending = try queue.pending(scope: scope)
        guard case .updatePage(_, _, let patchedDocument) = try #require(pending.first?.payload) else {
            Issue.record("Expected a queued page update")
            return
        }
        let mark = try #require(patchedDocument.content.first?.content?.first?.marks?.first)
        #expect(mark.attrs?["commentId"] == .string("comment-1"))
    }

    @Test func failedMutationStaysQueuedForRetry() throws {
        let queue = makeQueue()
        let record = try queue.enqueue(.removePageLabel(pageId: "page-1", labelId: "label-1"), scope: scope)

        try queue.markFailed(id: record.id, scope: scope, message: "Workspace unavailable")

        let pending = try queue.pending(scope: scope)
        let failed = try #require(pending.first)
        #expect(failed.id == record.id)
        #expect(failed.attemptCount == 1)
        #expect(failed.lastErrorMessage == "Workspace unavailable")
    }

    @Test func removingMutationDeletesOnlyMatchingScope() throws {
        let queue = makeQueue()
        let record = try queue.enqueue(.watchPage(pageId: "page-1"), scope: scope)

        try queue.remove(id: record.id, scope: CacheScope(serverBaseURL: "https://docs.example.com", userID: "user-2"))
        #expect(try queue.pending(scope: scope).map(\.id) == [record.id])

        try queue.remove(id: record.id, scope: scope)
        #expect(try queue.pending(scope: scope).isEmpty)
    }

    private func makeQueue() -> OfflineMutationQueue {
        let container = DocmostlyModelContainer.make(isStoredInMemoryOnly: true)
        return OfflineMutationQueue(context: ModelContext(container))
    }
}
