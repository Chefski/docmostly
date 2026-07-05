import Foundation
import Testing
@testable import docmostly

struct PageHistoryDecodingTests {
    @Test func decodesPaginatedPageHistoryMetadataAndDetailContent() throws {
        let data = Data("""
        {
          "items": [
            {
              "id": "history-1",
              "pageId": "page-1",
              "title": "Roadmap",
              "content": {
                "type": "doc",
                "content": [
                  {
                    "type": "paragraph",
                    "content": [{ "type": "text", "text": "Older body" }]
                  }
                ]
              },
              "slug": "roadmap",
              "icon": null,
              "coverPhoto": null,
              "version": 4,
              "lastUpdatedById": "user-1",
              "workspaceId": "workspace-1",
              "createdAt": "2026-07-04T09:00:00.000Z",
              "updatedAt": "2026-07-04T09:01:00.000Z",
              "lastUpdatedBy": {
                "id": "user-1",
                "name": "Ada",
                "avatarUrl": null
              },
              "contributors": [
                {
                  "id": "user-2",
                  "name": "Grace",
                  "avatarUrl": "https://docs.example.com/grace.png"
                }
              ]
            }
          ],
          "meta": {
            "limit": 20,
            "hasNextPage": true,
            "hasPrevPage": false,
            "nextCursor": "cursor-2",
            "prevCursor": null
          }
        }
        """.utf8)

        let response = try DocmostJSONDecoder.make().decode(
            PaginatedResponse<DocmostPageHistory>.self,
            from: data
        )
        let history = try #require(response.items.first)

        #expect(history.id == "history-1")
        #expect(history.version == 4)
        #expect(history.lastUpdatedBy?.name == "Ada")
        #expect(history.contributors?.first?.name == "Grace")
        #expect(history.content?.content.first?.type == "paragraph")
        #expect(response.meta.nextCursor == "cursor-2")
    }

    @Test func decodesPageHistoryWithNullVersionFromLiveDeployments() throws {
        let data = Data("""
        {
          "id": "history-1",
          "pageId": "page-1",
          "title": "Roadmap",
          "content": null,
          "slug": "roadmap",
          "icon": null,
          "coverPhoto": null,
          "version": null,
          "lastUpdatedById": "user-1",
          "workspaceId": "workspace-1",
          "createdAt": "2026-07-04T09:00:00.000Z",
          "updatedAt": "2026-07-04T09:01:00.000Z",
          "lastUpdatedBy": null,
          "contributors": []
        }
        """.utf8)

        let history = try DocmostJSONDecoder.make().decode(DocmostPageHistory.self, from: data)

        #expect(history.version == nil)
        #expect(history.title == "Roadmap")
    }
}
