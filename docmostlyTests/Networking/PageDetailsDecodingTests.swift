import Foundation
import Testing
@testable import docmostly

struct PageDetailsDecodingTests {
    @Test func decodesUntitledEditablePageWithNullTitle() throws {
        let data = Data("""
        {
          "id": "page-1",
          "slugId": "new-note",
          "title": null,
          "content": null,
          "spaceId": "space-1"
        }
        """.utf8)

        let page = try DocmostJSONDecoder.make().decode(DocmostEditablePage.self, from: data)

        #expect(page.title == "")
        #expect(page.content == nil)
    }

    @Test func editablePageKeepsDetailsMetadata() throws {
        let data = Data("""
        {
          "data": {
            "id": "page-1",
            "slugId": "roadmap",
            "title": "Roadmap",
            "content": { "type": "doc", "content": [] },
            "icon": "📄",
            "spaceId": "space-1",
            "createdAt": "2026-07-04T09:00:00.000Z",
            "updatedAt": "2026-07-04T10:30:00.000Z",
            "permissions": { "canEdit": true, "hasRestriction": false, "canManage": true },
            "creator": { "id": "user-1", "name": "Ada Lovelace", "avatarUrl": null },
            "lastUpdatedBy": { "id": "user-2", "name": "Grace Hopper", "avatarUrl": null }
          },
          "success": true,
          "status": 200
        }
        """.utf8)

        let envelope = try DocmostJSONDecoder.make().decode(
            APIEnvelope<DocmostEditablePage>.self,
            from: data
        )
        let page = envelope.data

        #expect(page.creator?.name == "Ada Lovelace")
        #expect(page.lastUpdatedBy?.name == "Grace Hopper")
        #expect(page.createdAt?.formatted(.iso8601.year().month().day()) == "2026-07-04")
        #expect(page.updatedAt == (try? Date(
            "2026-07-04T10:30:00.000Z",
            strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        )))
    }

    @Test func decodesBacklinkCountsAndPages() throws {
        let countsData = Data("""
        {
          "data": { "incoming": 2, "outgoing": 1 },
          "success": true,
          "status": 200
        }
        """.utf8)
        let counts = try DocmostJSONDecoder.make().decode(
            APIEnvelope<DocmostBacklinkCounts>.self,
            from: countsData
        )
        #expect(counts.data.incoming == 2)
        #expect(counts.data.outgoing == 1)

        let pagesData = Data("""
        {
          "data": {
            "items": [
              {
                "id": "page-2",
                "slugId": "linked-page",
                "title": "Linked Page",
                "icon": "🔗",
                "spaceId": "space-1",
                "updatedAt": "2026-07-04T10:00:00.000Z",
                "space": { "id": "space-1", "name": "Product", "slug": "product" }
              }
            ],
            "meta": {
              "limit": 25,
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
        let pages = try DocmostJSONDecoder.make().decode(
            APIEnvelope<PaginatedResponse<DocmostBacklinkPage>>.self,
            from: pagesData
        )
        let page = try #require(pages.data.items.first)

        #expect(page.title == "Linked Page")
        #expect(page.space?.name == "Product")
    }
}
