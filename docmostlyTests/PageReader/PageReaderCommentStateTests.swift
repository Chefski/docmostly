import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct PageReaderCommentStateTests {
    @Test func appliesUpdatedCommentWithoutChangingListOrder() throws {
        let viewModel = PageReaderViewModel()
        viewModel.comments = [
            try comment(id: "comment-1", text: "Open", resolvedAt: nil),
            try comment(id: "comment-2", text: "Needs decision", resolvedAt: nil)
        ]

        let resolvedAt = "2026-06-17T10:05:00.000Z"
        let updatedComment = try comment(id: "comment-2", text: "Needs decision", resolvedAt: resolvedAt)
        let expectedResolvedAt = try resolvedDate(resolvedAt)

        viewModel.applyUpdatedComment(updatedComment)

        #expect(viewModel.comments.map(\.id) == ["comment-1", "comment-2"])
        #expect(viewModel.comments[1].resolvedAt == expectedResolvedAt)
    }

    @Test func removesDeletedCommentByID() throws {
        let viewModel = PageReaderViewModel()
        viewModel.comments = [
            try comment(id: "comment-1", text: "Keep", resolvedAt: nil),
            try comment(id: "comment-2", text: "Delete", resolvedAt: nil)
        ]

        viewModel.removeComment(id: "comment-2")

        #expect(viewModel.comments.map(\.id) == ["comment-1"])
    }

    @Test func createdCommentIsAppendedOnce() throws {
        let viewModel = PageReaderViewModel()
        let existingComment = try comment(id: "comment-1", text: "Existing", resolvedAt: nil)
        let newComment = try comment(id: "comment-2", text: "New", resolvedAt: nil)
        viewModel.comments = [existingComment]

        viewModel.applyCreatedComment(newComment)
        viewModel.applyCreatedComment(newComment)

        #expect(viewModel.comments.map(\.id) == ["comment-1", "comment-2"])
    }

    @Test func updateForMissingCommentDoesNotInsertOutOfOrderComment() throws {
        let viewModel = PageReaderViewModel()
        let existingComment = try comment(id: "comment-1", text: "Existing", resolvedAt: nil)
        let missingComment = try comment(id: "comment-2", text: "Updated elsewhere", resolvedAt: nil)
        viewModel.comments = [existingComment]

        viewModel.applyUpdatedComment(missingComment)

        #expect(viewModel.comments.map(\.id) == ["comment-1"])
    }

    @Test func realtimeCommentUpdatedResolutionUpdatesInlineMark() async throws {
        let view = PageReaderView(pageID: "page-1")
        let block = NativeEditorBlock(
            kind: .paragraph,
            text: markedText("Marked text", commentID: "comment-1"),
            alignment: .left
        )
        let editorViewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        editorViewModel.document = NativeEditorDocument(blocks: [block])
        editorViewModel.lastSavedDocument = editorViewModel.document
        editorViewModel.resetEditingHistory()
        let resolvedComment = try comment(
            id: "comment-1",
            text: "Resolved",
            resolvedAt: "2026-06-17T10:05:00.000Z",
            type: "inline"
        )

        await view.handleRealtimeEvent(
            .commentUpdated(NativeEditorRealtimeCommentEvent(pageID: "page-1", comment: resolvedComment)),
            editorViewModel: editorViewModel
        )

        let marks = editorViewModel.document.proseMirrorDocument.content.first?.content?.first?.marks ?? []
        #expect(marks.contains(ProseMirrorMark(
            type: "comment",
            attrs: ["commentId": .string("comment-1"), "resolved": .bool(true)]
        )))
        #expect(editorViewModel.isDirty == false)
    }

    @Test func inlineCommentCreatedNeedsSnapshotRefreshWithoutCRDTEngine() throws {
        let editorViewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        let inlineComment = try comment(id: "comment-1", text: "Inline", resolvedAt: nil, type: "inline")
        let pageComment = try comment(id: "comment-2", text: "Page", resolvedAt: nil, type: "page")

        #expect(editorViewModel.needsRemoteSnapshotRefresh(forCreatedComment: inlineComment) == true)
        #expect(editorViewModel.needsRemoteSnapshotRefresh(forCreatedComment: pageComment) == false)
    }

    @Test func inlineCommentCreatedUsesCRDTEngineWithoutSnapshotRefresh() throws {
        let editorViewModel = NativeRichEditorViewModel(
            pageID: "page-1",
            initialTitle: "Page",
            crdtDocumentEngine: CommentCreationRefreshCRDTDocumentEngine()
        )
        let inlineComment = try comment(id: "comment-1", text: "Inline", resolvedAt: nil, type: "inline")

        #expect(editorViewModel.needsRemoteSnapshotRefresh(forCreatedComment: inlineComment) == false)
    }

    private func comment(id: String, text: String, resolvedAt: String?) throws -> DocmostComment {
        try comment(id: id, text: text, resolvedAt: resolvedAt, type: "page")
    }

    private func comment(id: String, text: String, resolvedAt: String?, type: String) throws -> DocmostComment {
        let resolvedAtJSON = resolvedAt.map { "\"\($0)\"" } ?? "null"
        let data = Data("""
        {
          "id": "\(id)",
          "content": "\(text)",
          "selection": null,
          "type": "\(type)",
          "creatorId": "user-1",
          "pageId": "page-1",
          "parentCommentId": null,
          "resolvedById": null,
          "resolvedAt": \(resolvedAtJSON),
          "workspaceId": "workspace-1",
          "createdAt": "2026-06-17T09:00:00.000Z",
          "editedAt": null,
          "deletedAt": null,
          "creator": {
            "id": "user-1",
            "name": "Chefling",
            "email": "chefling@example.com"
          }
        }
        """.utf8)

        return try DocmostJSONDecoder.make().decode(DocmostComment.self, from: data)
    }

    private func markedText(_ text: String, commentID: String) -> AttributedString {
        var attributedText = AttributedString(text)
        attributedText[NativeEditorCommentIDAttribute.self] = commentID
        attributedText[NativeEditorCommentResolvedAttribute.self] = false
        attributedText.backgroundColor = .yellow.opacity(0.28)
        return attributedText
    }

    private func resolvedDate(_ value: String) throws -> Date {
        try Date(value, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }
}

@MainActor
private final class CommentCreationRefreshCRDTDocumentEngine: NativeEditorCRDTDocumentEngine {
    func encodeStateVector() async throws -> Data {
        Data()
    }

    func encodeStateAsUpdate(for stateVector: Data) async throws -> Data {
        Data()
    }

    func applyRemoteUpdate(_ update: Data) async throws { }

    func flushPendingLocalChanges(
        title: String,
        document: NativeEditorDocument
    ) async throws -> NativeEditorCRDTSaveResult {
        NativeEditorCRDTSaveResult()
    }
}
