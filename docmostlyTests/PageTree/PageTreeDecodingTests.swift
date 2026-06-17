import Foundation
import Testing
@testable import docmostly

struct PageTreeDecodingTests {
    @Test func decodesSidebarPagePagination() throws {
        let data = Data("""
        {
          "data": {
            "items": [
              {
                "id": "page-1",
                "slugId": "abc123",
                "title": "Roadmap",
                "content": null,
                "icon": "📄",
                "coverPhoto": null,
                "parentPageId": null,
                "creatorId": "user-1",
                "spaceId": "space-1",
                "workspaceId": "workspace-1",
                "isLocked": false,
                "lastUpdatedById": "user-1",
                "createdAt": "2026-06-17T09:00:00.000Z",
                "updatedAt": "2026-06-17T09:05:00.000Z",
                "deletedAt": null,
                "position": "a0",
                "hasChildren": true,
                "permissions": { "canEdit": true, "hasRestriction": false }
              }
            ],
            "meta": {
              "limit": 100,
              "hasNextPage": false,
              "hasPrevPage": false,
              "nextCursor": null,
              "prevCursor": null
            }
          },
          "success": true,
          "status": 200
        }
        """.utf8)

        let envelope = try DocmostJSONDecoder.make().decode(
            APIEnvelope<PaginatedResponse<DocmostPage>>.self,
            from: data
        )
        let page = try #require(envelope.data.items.first)

        #expect(page.id == "page-1")
        #expect(page.slugId == "abc123")
        #expect(page.title == "Roadmap")
        #expect(page.hasChildren == true)
        #expect(page.permissions?.canEdit == true)
    }
}
