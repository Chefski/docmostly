import Foundation
import Testing
@testable import docmostly

struct TransclusionDecodingTests {
    @Test func decodesResolvedNotFoundAndNoAccessResults() throws {
        let data = Data("""
        {
          "data": {
            "items": [
              {
                "sourcePageId": "page-1",
                "transclusionId": "sync-1",
                "content": {
                  "type": "doc",
                  "content": [
                    {
                      "type": "paragraph",
                      "content": [{ "type": "text", "text": "Daily update" }]
                    }
                  ]
                },
                "sourceUpdatedAt": "2026-07-10T09:30:00.000Z"
              },
              {
                "sourcePageId": "page-2",
                "transclusionId": "sync-2",
                "status": "not_found"
              },
              {
                "sourcePageId": "page-3",
                "transclusionId": "sync-3",
                "status": "no_access"
              }
            ]
          },
          "success": true,
          "status": 200
        }
        """.utf8)

        let envelope = try DocmostJSONDecoder.make().decode(
            APIEnvelope<DocmostTransclusionLookupResponse>.self,
            from: data
        )

        #expect(envelope.data.items.count == 3)
        guard case .resolved(let reference, let content, let updatedAt) = envelope.data.items[0] else {
            Issue.record("Expected a resolved synced block.")
            return
        }
        #expect(reference == DocmostTransclusionReference(sourcePageId: "page-1", transclusionId: "sync-1"))
        #expect(content.content.first?.content?.first?.text == "Daily update")
        #expect(updatedAt == (try? Date(
            "2026-07-10T09:30:00.000Z",
            strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        )))
        #expect(envelope.data.items[1].status == .notFound)
        #expect(envelope.data.items[2].status == .noAccess)
    }

    @Test func rejectsUnknownLookupStatus() {
        let data = Data("""
        {
          "items": [
            {
              "sourcePageId": "page-1",
              "transclusionId": "sync-1",
              "status": "deleted"
            }
          ]
        }
        """.utf8)

        #expect(throws: DecodingError.self) {
            try DocmostJSONDecoder.make().decode(DocmostTransclusionLookupResponse.self, from: data)
        }
    }
}
