import Foundation
import Testing
@testable import docmostly

struct CommentDecodingTests {
    @Test func decodesJSONContentAsPlainText() throws {
        let data = Data("""
        {
          "id": "comment-1",
          "content": {
            "type": "doc",
            "content": [
              {
                "type": "paragraph",
                "content": [
                  { "type": "text", "text": "DM smoke test" }
                ]
              }
            ]
          },
          "selection": null,
          "type": "page",
          "creatorId": "user-1",
          "pageId": "page-1",
          "parentCommentId": null,
          "resolvedById": null,
          "resolvedAt": null,
          "workspaceId": "workspace-1",
          "createdAt": "2026-06-17T10:05:00.000Z",
          "editedAt": null,
          "deletedAt": null,
          "creator": {
            "id": "user-1",
            "name": "Chefling",
            "email": "chefling@example.com"
          }
        }
        """.utf8)

        let comment = try DocmostJSONDecoder.make().decode(DocmostComment.self, from: data)

        #expect(comment.content == "DM smoke test")
        #expect(comment.creator?.name == "Chefling")
        #expect(comment.isNativelyEditable)
    }

    @Test func richJSONContentIsNotNativelyEditable() throws {
        let data = commentData(contentJSON: """
        {
          "type": "doc",
          "content": [
            {
              "type": "paragraph",
              "content": [
                {
                  "type": "text",
                  "text": "Docmost",
                  "marks": [
                    { "type": "link", "attrs": { "href": "https://docmost.com" } }
                  ]
                }
              ]
            }
          ]
        }
        """)

        let comment = try DocmostJSONDecoder.make().decode(DocmostComment.self, from: data)

        #expect(comment.content == "Docmost")
        #expect(comment.isNativelyEditable == false)
    }

    @Test func multiParagraphPlainJSONContentIsNativelyEditable() throws {
        let data = commentData(contentJSON: """
        {
          "type": "doc",
          "content": [
            {
              "type": "paragraph",
              "content": [
                { "type": "text", "text": "First " },
                { "type": "text", "text": "paragraph" }
              ]
            },
            {
              "type": "paragraph",
              "content": [
                { "type": "text", "text": "Second paragraph" }
              ]
            }
          ]
        }
        """)

        let comment = try DocmostJSONDecoder.make().decode(DocmostComment.self, from: data)

        #expect(comment.content == "First paragraph\nSecond paragraph")
        #expect(comment.isNativelyEditable)
    }

    @Test func plainTextPayloadEncodesLineBreaksAsParagraphs() throws {
        let data = try #require(
            CommentPayload.plainText("First paragraph\nSecond paragraph").jsonString.data(using: .utf8)
        )
        let payload = try JSONDecoder().decode(EncodedCommentPayload.self, from: data)

        #expect(payload.type == "doc")
        #expect(payload.content.map(\.text) == ["First paragraph", "Second paragraph"])
    }

    @Test func decodesThreadedCommentsFromFlatPageResponse() throws {
        let data = Data("""
        {
          "items": [
            {
              "id": "parent-1",
              "content": "Parent",
              "selection": null,
              "type": "page",
              "creatorId": "user-1",
              "pageId": "page-1",
              "parentCommentId": null,
              "resolvedById": null,
              "resolvedAt": null,
              "workspaceId": "workspace-1",
              "createdAt": "2026-06-17T10:05:00.000Z",
              "editedAt": null,
              "deletedAt": null,
              "creator": { "id": "user-1", "name": "Chefling", "email": "chefling@example.com" }
            },
            {
              "id": "reply-1",
              "content": "Reply",
              "selection": null,
              "type": "page",
              "creatorId": "user-2",
              "pageId": "page-1",
              "parentCommentId": "parent-1",
              "resolvedById": null,
              "resolvedAt": null,
              "workspaceId": "workspace-1",
              "createdAt": "2026-06-17T10:06:00.000Z",
              "editedAt": null,
              "deletedAt": null,
              "creator": { "id": "user-2", "name": "Reply User", "email": "reply@example.com" }
            }
          ],
          "meta": {
            "limit": 100,
            "hasNextPage": false,
            "hasPrevPage": false,
            "nextCursor": null,
            "prevCursor": null
          }
        }
        """.utf8)

        let response = try DocmostJSONDecoder.make().decode(PaginatedResponse<DocmostComment>.self, from: data)

        #expect(response.items.map(\.id) == ["parent-1", "reply-1"])
        #expect(response.items[0].parentCommentId == nil)
        #expect(response.items[1].parentCommentId == "parent-1")
        #expect(response.items[1].content == "Reply")
    }

    @Test func rejectsDeeplyNestedCommentContent() throws {
        let nestedContent = (0..<(CommentContentDecodingLimits.maximumDepth + 1)).reduce(
            #"{"type":"text","text":"Too deep"}"#
        ) { content, _ in
            #"{"type":"paragraph","content":["# + content + #"]}"#
        }
        let data = commentData(contentJSON: nestedContent)

        let comment = try DocmostJSONDecoder.make().decode(DocmostComment.self, from: data)

        #expect(comment.content == nil)
        #expect(comment.isNativelyEditable == false)
    }

    @Test func rejectsOversizedCommentText() throws {
        let content = """
        {
          "type": "doc",
          "content": [
            {
              "type": "paragraph",
              "content": [
                { "type": "text", "text": "\(String(
                    repeating: "A",
                    count: CommentContentDecodingLimits.maximumTextLength + 1
                ))" }
              ]
            }
          ]
        }
        """
        let data = commentData(contentJSON: content)

        let comment = try DocmostJSONDecoder.make().decode(DocmostComment.self, from: data)

        #expect(comment.content == nil)
        #expect(comment.isNativelyEditable == false)
    }

    private func commentData(contentJSON: String) -> Data {
        Data("""
        {
          "id": "comment-1",
          "content": \(contentJSON),
          "selection": null,
          "type": "page",
          "creatorId": "user-1",
          "pageId": "page-1",
          "parentCommentId": null,
          "resolvedById": null,
          "resolvedAt": null,
          "workspaceId": "workspace-1",
          "createdAt": "2026-06-17T10:05:00.000Z",
          "editedAt": null,
          "deletedAt": null,
          "creator": {
            "id": "user-1",
            "name": "Chefling",
            "email": "chefling@example.com"
          }
        }
        """.utf8)
    }
}

private struct EncodedCommentPayload: Decodable {
    let type: String
    let content: [EncodedCommentParagraph]
}

private struct EncodedCommentParagraph: Decodable {
    let content: [EncodedCommentText]

    var text: String {
        content.map(\.text).joined()
    }
}

private struct EncodedCommentText: Decodable {
    let text: String
}
