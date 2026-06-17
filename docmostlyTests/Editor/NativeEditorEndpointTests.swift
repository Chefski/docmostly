import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorEndpointTests {
    @Test func updatePageBuildsDocmostReplaceRequest() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let document = NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .paragraph, text: AttributedString("Updated page"), alignment: .left)
        ])

        let request = try Endpoint.updatePage(
            pageId: "page-1",
            title: "Updated title",
            content: document.proseMirrorDocument,
            format: .json,
            operation: .replace
        )
        .urlRequest(baseURL: baseURL)

        #expect(request.url?.absoluteString == "https://docs.example.com/api/pages/update")
        #expect(request.httpMethod == "POST")

        let body = try #require(request.httpBody)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        let content = try #require(object["content"] as? [String: Any])

        #expect(object["pageId"] as? String == "page-1")
        #expect(object["title"] as? String == "Updated title")
        #expect(object["operation"] as? String == "replace")
        #expect(object["format"] as? String == "json")
        #expect(content["type"] as? String == "doc")
    }
}
