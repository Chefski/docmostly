import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct CommentBodyTests {
    @Test func composerSerializesFormattingAndSafeLinksToDocmostJSON() throws {
        let draft = CommentComposerState(body: CommentBody(plainText: "Docmost"))
        draft.selection = AttributedTextSelection(range: draft.text.startIndex..<draft.text.endIndex)

        draft.toggle(.bold)
        try draft.applyLink("docmost.com")

        let node = try #require(draft.body.document.content.first?.content?.first)
        #expect(node.text == "Docmost")
        #expect(node.marks?.contains(ProseMirrorMark(type: "bold")) == true)
        #expect(node.marks?.contains(where: { mark in
            mark.type == "link" && mark.attrs?["href"]?.stringValue == "http://docmost.com"
        }) == true)

        let decoded = try ProseMirrorDocument.decode(from: Data(draft.body.jsonString.utf8))
        #expect(decoded == draft.body.document)
    }

    @Test func composerRejectsUnsafeLinksWithoutChangingText() throws {
        let draft = CommentComposerState(body: CommentBody(plainText: "Open"))
        draft.selection = AttributedTextSelection(range: draft.text.startIndex..<draft.text.endIndex)

        #expect(throws: CommentLinkValidationError.invalidURL) {
            try draft.applyLink("javascript:alert(1)")
        }
        #expect(draft.plainText == "Open")
        #expect(draft.body.document.content.first?.content?.first?.marks?.isEmpty != false)
    }

    @Test func mentionTriggerSerializesWebCompatibleUserAttributes() throws {
        let user = try JSONDecoder().decode(
            DocmostMentionUserSuggestion.self,
            from: Data(#"{"id":"user-7","name":"Ada Lovelace","email":"ada@example.com","avatarUrl":null}"#.utf8)
        )
        let draft = CommentComposerState(body: CommentBody(plainText: "Thanks @ad"))
        draft.selection = AttributedTextSelection(insertionPoint: draft.text.endIndex)

        draft.insertMention(user, creatorID: "creator-1")

        let mention = try #require(draft.body.document.content.first?.content?.first { $0.type == "mention" })
        #expect(mention.attrs?["id"]?.stringValue?.isEmpty == false)
        #expect(mention.attrs?["label"]?.stringValue == "Ada Lovelace")
        #expect(mention.attrs?["entityType"]?.stringValue == "user")
        #expect(mention.attrs?["entityId"]?.stringValue == "user-7")
        #expect(mention.attrs?["creatorId"]?.stringValue == "creator-1")
        #expect(draft.plainText == "Thanks @Ada Lovelace ")
    }

    @Test func emojiTriggerReplacesOnlyTheActiveQuery() {
        let draft = CommentComposerState(body: CommentBody(plainText: "Looks :thu"))
        draft.selection = AttributedTextSelection(insertionPoint: draft.text.endIndex)

        draft.insertEmoji(CommentEmoji.all.first { $0.name == "thumbs up" } ?? CommentEmoji.all[0])

        #expect(draft.plainText == "Looks 👍 ")
    }

    @Test func permissionPolicyMatchesDocmostOwnershipAndAdminRules() {
        let comment = DocmostComment(
            id: "comment-1",
            content: "Review",
            selection: nil,
            type: DocmostCommentType.page.rawValue,
            creatorId: "owner-1",
            pageId: "page-1"
        )

        #expect(CommentPermissionPolicy.canCreate(pageCanEdit: false, allowViewerComments: true))
        #expect(CommentPermissionPolicy.canEdit(
            comment,
            currentUserID: "owner-1",
            canComment: true,
            isOnline: true
        ))
        #expect(CommentPermissionPolicy.canEdit(
            comment,
            currentUserID: "other-user",
            canComment: true,
            isOnline: true
        ) == false)
        #expect(CommentPermissionPolicy.canDelete(
            comment,
            currentUserID: "other-user",
            isSpaceAdmin: true,
            isOnline: true
        ))
        #expect(CommentPermissionPolicy.canResolve(comment, canComment: true, isOnline: false) == false)
    }

    @Test func failedEditRetainsRichDraftAndSurfacesRowError() async throws {
        let loader = CommentFailureHTTPDataLoader()
        let client = DocmostAPIClient(
            baseURL: try #require(URL(string: "https://docs.example.com")),
            loader: loader
        )
        let appState = AppState(apiClient: client)
        let viewModel = PageReaderViewModel()
        let comment = DocmostComment(
            id: "comment-1",
            content: "Original",
            selection: nil,
            type: DocmostCommentType.page.rawValue,
            creatorId: "owner-1",
            pageId: "page-1"
        )
        viewModel.comments = [comment]
        viewModel.beginEditing(comment)
        let draft = try #require(viewModel.editDraftsByCommentID[comment.id])
        draft.reset(body: CommentBody(plainText: "Updated with context"))

        await viewModel.updateComment(comment, appState: appState)

        #expect(viewModel.comments.first?.content == "Original")
        #expect(viewModel.editDraftsByCommentID[comment.id]?.plainText == "Updated with context")
        #expect(viewModel.isEditingComment(id: comment.id))
        #expect(viewModel.commentErrorsByID[comment.id] == "You cannot edit this comment.")
    }

    @Test func createCommentSendsRichDocumentAsJSONStringAPIField() async throws {
        let loader = CommentCapturingHTTPDataLoader()
        let client = DocmostAPIClient(
            baseURL: try #require(URL(string: "https://docs.example.com")),
            loader: loader
        )
        let appState = AppState(apiClient: client)
        let draft = CommentComposerState(body: CommentBody(plainText: "Ship it"))
        draft.selection = AttributedTextSelection(range: draft.text.startIndex..<draft.text.endIndex)
        draft.toggle(.italic)

        _ = try await appState.addPageComment(pageId: "page-1", body: draft.body)

        let request = try #require(await loader.request)
        let requestData = try #require(request.httpBody)
        let requestBody = try #require(
            JSONSerialization.jsonObject(with: requestData) as? [String: Any]
        )
        let content = try #require(requestBody["content"] as? String)
        let document = try ProseMirrorDocument.decode(from: Data(content.utf8))
        #expect(request.url?.path == "/api/comments/create")
        #expect(requestBody["pageId"] as? String == "page-1")
        #expect(requestBody["type"] as? String == "page")
        #expect(document.content.first?.content?.first?.marks == [ProseMirrorMark(type: "italic")])
    }

    @Test func inlineAnchorLookupFindsMarkedEditorBlock() {
        let targetBlockID = UUID()
        var markedText = AttributedString("Anchored")
        markedText.setNativeEditorInlineComments(
            [NativeEditorInlineCommentMark(commentID: "comment-1", isResolved: false)]
        )
        let editorViewModel = NativeRichEditorViewModel(pageID: "page-1")
        editorViewModel.document = NativeEditorDocument(blocks: [
            NativeEditorBlock(
                id: targetBlockID,
                kind: .paragraph,
                text: markedText,
                alignment: .left
            )
        ])

        #expect(editorViewModel.blockID(containingInlineComment: "comment-1") == targetBlockID)
        #expect(editorViewModel.blockID(containingInlineComment: "missing") == nil)
    }
}

private actor CommentFailureHTTPDataLoader: HTTPDataLoading {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: 403,
                httpVersion: "HTTP/1.1",
                headerFields: nil
              ) else {
            throw APIError.invalidResponse
        }
        return (Data(#"{"message":"You cannot edit this comment."}"#.utf8), response)
    }

    func upload(for request: URLRequest, fromFile fileURL: URL) async throws -> (Data, URLResponse) {
        throw APIError.invalidResponse
    }
}

private actor CommentCapturingHTTPDataLoader: HTTPDataLoading {
    private(set) var request: URLRequest?

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        self.request = request
        guard let url = request.url,
              let response = HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
              ) else {
            throw APIError.invalidResponse
        }

        let data = Data("""
        {
          "data": {
            "id": "comment-1",
            "content": {
              "type": "doc",
              "content": [{
                "type": "paragraph",
                "content": [{
                  "type": "text",
                  "text": "Ship it",
                  "marks": [{ "type": "italic" }]
                }]
              }]
            },
            "selection": null,
            "type": "page",
            "creatorId": "user-1",
            "pageId": "page-1",
            "parentCommentId": null,
            "resolvedById": null,
            "resolvedAt": null,
            "workspaceId": "workspace-1",
            "spaceId": "space-1",
            "createdAt": "2026-07-18T10:00:00.000Z",
            "editedAt": null,
            "deletedAt": null
          },
          "success": true,
          "status": 200
        }
        """.utf8)
        return (data, response)
    }

    func upload(for request: URLRequest, fromFile fileURL: URL) async throws -> (Data, URLResponse) {
        throw APIError.invalidResponse
    }
}
