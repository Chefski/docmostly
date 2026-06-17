import Foundation
import Testing
@testable import docmostly

struct SearchResponseDecodingTests {
    @Test func decodesPageSearchEnvelope() throws {
        let data = Data("""
        {
          "data": {
            "items": [
              {
                "id": "page-1",
                "title": "Roadmap",
                "icon": "",
                "parentPageId": null,
                "slugId": "abc123",
                "creatorId": "user-1",
                "createdAt": "2026-06-17T09:00:00.000Z",
                "updatedAt": "2026-06-17T09:05:00.000Z",
                "rank": 0.42,
                "highlight": "Quarterly <b>roadmap</b>",
                "space": {
                  "id": "space-1",
                  "name": "Product",
                  "slug": "product"
                }
              }
            ]
          },
          "success": true,
          "status": 200
        }
        """.utf8)

        let envelope = try DocmostJSONDecoder.make().decode(APIEnvelope<SearchResponse>.self, from: data)
        let result = try #require(envelope.data.items.first)

        #expect(result.title == "Roadmap")
        #expect(result.rank == 0.42)
        #expect(result.highlight == "Quarterly <b>roadmap</b>")
        #expect(result.space.name == "Product")
    }
}
