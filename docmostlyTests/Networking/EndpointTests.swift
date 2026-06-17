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
        let yjsSelection = NativeEditorYjsSelection(
            anchor: NativeEditorYjsSelectionPosition(
                type: NativeEditorYjsID(client: 1, clock: 10),
                targetName: nil,
                item: NativeEditorYjsID(client: 1, clock: 11),
                assoc: 0
            ),
            head: NativeEditorYjsSelectionPosition(
                type: NativeEditorYjsID(client: 1, clock: 12),
                targetName: nil,
                item: nil,
                assoc: -1
            )
        )
        let endpoint = Endpoint.createComment(
            pageId: "page-1",
            content: #"{"type":"doc","content":[]}"#,
            type: .inline,
            selection: "Selected text",
            yjsSelection: yjsSelection
        )
        let request = try endpoint.urlRequest(baseURL: baseURL)

        #expect(request.url?.absoluteString == "https://docs.example.com/api/comments/create")

        let body = try #require(request.httpBody)
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(object?["pageId"] as? String == "page-1")
        #expect(object?["content"] as? String == #"{"type":"doc","content":[]}"#)
        #expect(object?["type"] as? String == "inline")
        #expect(object?["selection"] as? String == "Selected text")
        let selection = try #require(object?["yjsSelection"] as? [String: Any])
        let anchor = try #require(selection["anchor"] as? [String: Any])
        let anchorType = try #require(anchor["type"] as? [String: Any])
        let anchorItem = try #require(anchor["item"] as? [String: Any])
        let head = try #require(selection["head"] as? [String: Any])
        let headType = try #require(head["type"] as? [String: Any])

        #expect(anchorType["client"] as? Int == 1)
        #expect(anchorType["clock"] as? Int == 10)
        #expect(anchor["tname"] is NSNull)
        #expect(anchorItem["clock"] as? Int == 11)
        #expect(anchor["assoc"] as? Int == 0)
        #expect(headType["clock"] as? Int == 12)
        #expect(head["item"] is NSNull)
        #expect(head["assoc"] as? Int == -1)
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
