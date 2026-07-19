import Foundation
import Testing
@testable import docmostly

struct TransclusionEndpointTests {
    @Test func buildsTypedTransclusionLookupRequest() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let endpoint = Endpoint.transclusionLookup(DocmostTransclusionLookupRequest(references: [
            DocmostTransclusionReference(sourcePageId: "page-1", transclusionId: "sync-1"),
            DocmostTransclusionReference(sourcePageId: "page-2", transclusionId: "sync-2")
        ]))
        let request = try endpoint.urlRequest(baseURL: baseURL)

        #expect(request.url?.absoluteString == "https://docs.example.com/api/pages/transclusion/lookup")
        #expect(request.httpMethod == "POST")

        let body = try #require(request.httpBody)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let references = try #require(object["references"] as? [[String: String]])

        #expect(references.count == 2)
        #expect(references[0]["sourcePageId"] == "page-1")
        #expect(references[0]["transclusionId"] == "sync-1")
        #expect(references[1]["sourcePageId"] == "page-2")
        #expect(references[1]["transclusionId"] == "sync-2")
    }
}
