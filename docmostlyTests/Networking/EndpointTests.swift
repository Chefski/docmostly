import Foundation
import Testing
@testable import docmostly

struct EndpointTests {
    @Test func buildsPostRequestUnderAPIPrefix() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let endpoint = Endpoint.pageInfo(pageId: "abc123", format: .html)
        let request = try endpoint.urlRequest(baseURL: baseURL)

        #expect(request.url?.absoluteString == "https://docs.example.com/api/pages/info")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let body = try #require(request.httpBody)
        let object = try JSONSerialization.jsonObject(with: body) as? [String: String]
        #expect(object?["pageId"] == "abc123")
        #expect(object?["format"] == "html")
    }

    @Test func buildsAuthenticatedSearchRequest() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let endpoint = Endpoint.search(query: "roadmap", spaceId: "space-1")
        let request = try endpoint.urlRequest(baseURL: baseURL)

        #expect(request.url?.path == "/api/search")

        let body = try #require(request.httpBody)
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(object?["query"] as? String == "roadmap")
        #expect(object?["spaceId"] as? String == "space-1")
    }

    @Test func omitsJSONContentTypeWhenPostBodyIsEmpty() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let request = try Endpoint.workspacePublic.urlRequest(baseURL: baseURL)

        #expect(request.httpMethod == "POST")
        #expect(request.httpBody == nil)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test func buildsCollaborationTokenRequest() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let request = try Endpoint.collabToken.urlRequest(baseURL: baseURL)

        #expect(request.url?.absoluteString == "https://docs.example.com/api/auth/collab-token")
        #expect(request.httpMethod == "POST")
        #expect(request.httpBody == nil)
    }

    @Test func buildsInlineCommentCreateRequest() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let endpoint = Endpoint.createComment(
            pageId: "page-1",
            content: #"{"type":"doc","content":[]}"#,
            type: .inline,
            selection: "Selected text"
        )
        let request = try endpoint.urlRequest(baseURL: baseURL)

        #expect(request.url?.absoluteString == "https://docs.example.com/api/comments/create")

        let body = try #require(request.httpBody)
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(object?["pageId"] as? String == "page-1")
        #expect(object?["content"] as? String == #"{"type":"doc","content":[]}"#)
        #expect(object?["type"] as? String == "inline")
        #expect(object?["selection"] as? String == "Selected text")
    }

    @Test func buildsResolveCommentRequest() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let endpoint = Endpoint.resolveComment(commentId: "comment-1", pageId: "page-1", resolved: true)
        let request = try endpoint.urlRequest(baseURL: baseURL)

        #expect(request.url?.absoluteString == "https://docs.example.com/api/comments/resolve")

        let body = try #require(request.httpBody)
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(object?["commentId"] as? String == "comment-1")
        #expect(object?["pageId"] as? String == "page-1")
        #expect(object?["resolved"] as? Bool == true)
    }
}
