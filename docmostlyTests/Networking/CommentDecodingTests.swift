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
    }
}
