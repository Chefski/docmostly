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

    @Test func commentTabsOnlyIncludeTopLevelCommentsSplitByResolution() throws {
        let viewModel = PageReaderViewModel()
        viewModel.comments = [
            try comment(id: "open-parent", text: "Open", resolvedAt: nil),
            try comment(id: "resolved-parent", text: "Resolved", resolvedAt: "2026-06-17T10:05:00.000Z"),
            try comment(id: "open-reply", text: "Reply", resolvedAt: nil, parentCommentId: "open-parent")
        ]

        #expect(viewModel.openComments.map(\.id) == ["open-parent"])
        #expect(viewModel.resolvedComments.map(\.id) == ["resolved-parent"])
        #expect(viewModel.openCommentCount == 1)
        #expect(viewModel.resolvedCommentCount == 1)
    }

    @Test func tableOfContentsItemsIncludeNonEmptyHeadingsThroughLevelFour() {
        let firstHeadingID = UUID()
        let fourthHeadingID = UUID()
        let document = NativeEditorDocument(blocks: [
            NativeEditorBlock(
                id: firstHeadingID,
                kind: .heading(level: 1),
                text: AttributedString("Overview"),
                alignment: .left
            ),
            NativeEditorBlock(kind: .paragraph, text: AttributedString("Body"), alignment: .left),
            NativeEditorBlock(kind: .heading(level: 2), text: AttributedString("   "), alignment: .left),
            NativeEditorBlock(
                id: fourthHeadingID,
                kind: .heading(level: 4),
                text: AttributedString("Details"),
                alignment: .left
            ),
            NativeEditorBlock(kind: .heading(level: 5), text: AttributedString("Ignored"), alignment: .left)
        ])

        #expect(PageReaderTableOfContentsItem.items(in: document) == [
            PageReaderTableOfContentsItem(id: firstHeadingID, title: "Overview", level: 1),
            PageReaderTableOfContentsItem(id: fourthHeadingID, title: "Details", level: 4)
        ])
    }

    private func comment(id: String, text: String, resolvedAt: String?) throws -> DocmostComment {
        try comment(id: id, text: text, resolvedAt: resolvedAt, type: "page", parentCommentId: nil)
    }

    private func comment(id: String, text: String, resolvedAt: String?, type: String) throws -> DocmostComment {
        try comment(id: id, text: text, resolvedAt: resolvedAt, type: type, parentCommentId: nil)
    }

    private func comment(
        id: String,
        text: String,
        resolvedAt: String?,
        parentCommentId: String?
    ) throws -> DocmostComment {
        try comment(id: id, text: text, resolvedAt: resolvedAt, type: "page", parentCommentId: parentCommentId)
    }

    private func comment(
        id: String,
        text: String,
        resolvedAt: String?,
        type: String,
        parentCommentId: String?
    ) throws -> DocmostComment {
        let resolvedAtJSON = resolvedAt.map { "\"\($0)\"" } ?? "null"
        let parentCommentIdJSON = parentCommentId.map { "\"\($0)\"" } ?? "null"
        let data = Data("""
        {
          "id": "\(id)",
          "content": "\(text)",
          "selection": null,
          "type": "\(type)",
          "creatorId": "user-1",
          "pageId": "page-1",
          "parentCommentId": \(parentCommentIdJSON),
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
