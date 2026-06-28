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
                pageId: "page-1",
                content: #"{"type":"doc","content":[]}"#,
                type: .page,
                selection: nil,
                yjsSelection: nil
            ),
            scope: scope
        )
        let second = try queue.enqueue(.addPageLabels(pageId: "page-1", names: ["ios", "offline"]), scope: scope)
        let third = try queue.enqueue(
            .movePage(pageId: "page-1", parentPageId: "parent-1", position: "a000001"),
            scope: scope
        )

        #expect(try queue.pending(scope: scope).map(\.id) == [first.id, second.id, third.id])
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
