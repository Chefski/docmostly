import Foundation
import SwiftData
import Testing
@testable import docmostly

@MainActor
struct OfflineQueueConflictResolutionTests {
    private let scope = CacheScope(serverBaseURL: "https://docs.example.com", userID: "user-1")

    @Test func keepMineAtomicallyRebasesPendingDraftToRejectedRemoteDocument() throws {
        let queue = makeQueue()
        let originalBase = document(text: "Original base")
        let remoteDocument = document(text: "Remote concurrent edit")
        let localDocument = document(text: "Retained local edit")
        let record = try queue.enqueue(
            .updatePage(
                pageId: "page-1",
                title: "Before resolution",
                document: localDocument,
                baseDocument: originalBase
            ),
            scope: scope
        )
        let resolvedAt = record.createdAt.addingTimeInterval(2)

        let result = try queue.resolvePendingPageUpdateKeepingLocal(
            pageId: "page-1",
            title: "Keep local",
            document: localDocument,
            remoteBaseDocument: remoteDocument,
            replacingThrough: record.createdAt.addingTimeInterval(1),
            resolvedAt: resolvedAt,
            scope: scope
        )

        let pending = try queue.pending(scope: scope)
        #expect(result == .superseded)
        #expect(pending.map(\.payload) == [
            .updatePage(
                pageId: "page-1",
                title: "Keep local",
                document: localDocument,
                baseDocument: remoteDocument
            )
        ])
        #expect(pending.first?.createdAt == resolvedAt)
    }

    @Test func keepMineDoesNotReplaceANewerPendingDraft() throws {
        let queue = makeQueue()
        let newerDocument = document(text: "Newer draft")
        let record = try queue.enqueue(
            .updatePage(pageId: "page-1", title: "Newer", document: newerDocument),
            scope: scope
        )

        let result = try queue.resolvePendingPageUpdateKeepingLocal(
            pageId: "page-1",
            title: "Older resolution",
            document: document(text: "Older local"),
            remoteBaseDocument: document(text: "Remote"),
            replacingThrough: record.createdAt.addingTimeInterval(-1),
            resolvedAt: record.createdAt,
            scope: scope
        )

        #expect(result == .newerPendingUpdatePreserved)
        #expect(try queue.pending(scope: scope).map(\.payload) == [
            .updatePage(pageId: "page-1", title: "Newer", document: newerDocument)
        ])
    }

    private func makeQueue() -> OfflineMutationQueue {
        let container = DocmostlyModelContainer.make(isStoredInMemoryOnly: true)
        return OfflineMutationQueue(context: ModelContext(container))
    }

    private func document(text: String) -> ProseMirrorDocument {
        ProseMirrorDocument(content: [
            ProseMirrorNode(
                type: "paragraph",
                content: [ProseMirrorNode(type: "text", text: text)]
            )
        ])
    }
}
