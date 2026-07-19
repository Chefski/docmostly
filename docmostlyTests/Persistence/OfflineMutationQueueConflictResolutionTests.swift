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
            remoteBaseTitle: "Remote title",
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
                baseTitle: "Remote title",
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
            remoteBaseTitle: "Remote title",
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

    @Test func keepMinePreservesQueuedYjsStateWhenResolvingATitleConflict() throws {
        let queue = makeQueue()
        let localDocument = document(text: "Merged collaborative body")
        let stateUpdate = Data([2, 7, 1, 8])
        let record = try queue.enqueue(
            .updatePageCRDT(
                pageId: "page-1",
                title: "Local title",
                document: localDocument,
                stateUpdate: stateUpdate,
                baseTitle: "Original title"
            ),
            scope: scope
        )

        let result = try queue.resolvePendingPageUpdateKeepingLocal(
            pageId: "page-1",
            title: "Local title",
            document: localDocument,
            remoteBaseTitle: "Remote title",
            remoteBaseDocument: document(text: "Remote REST projection"),
            replacingThrough: record.createdAt,
            resolvedAt: record.createdAt.addingTimeInterval(1),
            scope: scope
        )

        #expect(result == .superseded)
        #expect(try queue.pending(scope: scope).map(\.payload) == [
            .updatePageCRDT(
                pageId: "page-1",
                title: "Local title",
                document: localDocument,
                stateUpdate: stateUpdate,
                baseTitle: "Remote title"
            )
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
