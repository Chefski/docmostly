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
        #expect(request.httpShouldHandleCookies == false)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

        let body = try #require(request.httpBody)
        let object = try JSONSerialization.jsonObject(with: body) as? [String: String]
        #expect(object?["pageId"] == "abc123")
        #expect(object?["format"] == "html")
    }

    @Test func buildsAuthenticatedSearchRequest() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let endpoint = Endpoint.search(
            query: "roadmap",
            spaceId: "space-1",
            creatorId: "user-1",
            limit: 25,
            offset: 50
        )
        let request = try endpoint.urlRequest(baseURL: baseURL)

        #expect(request.url?.path == "/api/search")

        let body = try #require(request.httpBody)
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(object?["query"] as? String == "roadmap")
        #expect(object?["spaceId"] as? String == "space-1")
        #expect(object?["creatorId"] as? String == "user-1")
        #expect(object?["limit"] as? Int == 25)
        #expect(object?["offset"] as? Int == 50)
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

    @Test func buildsBaseCreateRequestWithKanbanTemplate() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let endpoint = Endpoint.createBase(parentPageId: "page-1", template: .kanban)
        let request = try endpoint.urlRequest(baseURL: baseURL)

        #expect(request.url?.absoluteString == "https://docs.example.com/api/bases/create")

        let body = try #require(request.httpBody)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: String])
        #expect(object["parentPageId"] == "page-1")
        #expect(object["template"] == "kanban")
    }

    @Test func buildsMentionSuggestionsRequestForUsersAndPages() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let endpoint = Endpoint.searchSuggestions(
            query: "road",
            includeUsers: true,
            includePages: true,
            spaceId: "space-1",
            limit: 10
        )
        let request = try endpoint.urlRequest(baseURL: baseURL)

        #expect(request.url?.absoluteString == "https://docs.example.com/api/search/suggest")

        let body = try #require(request.httpBody)
        let object = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object["query"] as? String == "road")
        #expect(object["includeUsers"] as? Bool == true)
        #expect(object["includePages"] as? Bool == true)
        #expect(object["spaceId"] as? String == "space-1")
        #expect(object["limit"] as? Int == 10)
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
            parentCommentId: nil,
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

    @Test func buildsReplyCommentCreateRequest() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let endpoint = Endpoint.createComment(
            pageId: "page-1",
            content: #"{"type":"doc","content":[]}"#,
            type: .page,
            selection: nil,
            parentCommentId: "parent-comment-1"
        )
        let request = try endpoint.urlRequest(baseURL: baseURL)

        #expect(request.url?.absoluteString == "https://docs.example.com/api/comments/create")

        let body = try #require(request.httpBody)
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(object?["pageId"] as? String == "page-1")
        #expect(object?["content"] as? String == #"{"type":"doc","content":[]}"#)
        #expect(object?["type"] as? String == "page")
        #expect(object?["parentCommentId"] as? String == "parent-comment-1")
        #expect(object?.keys.contains("selection") == false)
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

    @Test func buildsShareRequests() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))

        let forPage = try Endpoint.shareForPage(pageId: "page-1").urlRequest(baseURL: baseURL)
        #expect(forPage.url?.absoluteString == "https://docs.example.com/api/shares/for-page")
        #expect(try jsonBody(forPage)["pageId"] as? String == "page-1")

        let create = try Endpoint.createShare(
            pageId: "page-1",
            includeSubPages: true,
            searchIndexing: false
        ).urlRequest(baseURL: baseURL)
        #expect(create.url?.absoluteString == "https://docs.example.com/api/shares/create")
        let createBody = try jsonBody(create)
        #expect(createBody["pageId"] as? String == "page-1")
        #expect(createBody["includeSubPages"] as? Bool == true)
        #expect(createBody["searchIndexing"] as? Bool == false)

        let update = try Endpoint.updateShare(
            shareId: "share-1",
            includeSubPages: false
        ).urlRequest(baseURL: baseURL)
        #expect(update.url?.absoluteString == "https://docs.example.com/api/shares/update")
        let updateBody = try jsonBody(update)
        #expect(updateBody["shareId"] as? String == "share-1")
        #expect(updateBody["includeSubPages"] as? Bool == false)
        #expect(updateBody.keys.contains("searchIndexing") == false)

        let delete = try Endpoint.deleteShare(shareId: "share-1").urlRequest(baseURL: baseURL)
        #expect(delete.url?.absoluteString == "https://docs.example.com/api/shares/delete")
        #expect(try jsonBody(delete)["shareId"] as? String == "share-1")
    }

    @Test func buildsPageRestrictionReadRequests() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))

        let info = try Endpoint.pageRestrictionInfo(pageId: "page-1").urlRequest(baseURL: baseURL)
        #expect(info.url?.absoluteString == "https://docs.example.com/api/pages/permission-info")
        #expect(try jsonBody(info)["pageId"] as? String == "page-1")

        let members = try Endpoint.pagePermissions(pageId: "page-1", cursor: "cursor-1", limit: 25)
            .urlRequest(baseURL: baseURL)
        #expect(members.url?.absoluteString == "https://docs.example.com/api/pages/permissions")
        let body = try jsonBody(members)
        #expect(body["pageId"] as? String == "page-1")
        #expect(body["cursor"] as? String == "cursor-1")
        #expect(body["limit"] as? Int == 25)
    }

    @Test func buildsPageHistoryRequests() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))

        let list = try Endpoint.pageHistory(pageId: "page-1", cursor: "cursor-1", limit: 20)
            .urlRequest(baseURL: baseURL)
        #expect(list.url?.absoluteString == "https://docs.example.com/api/pages/history")
        let listBody = try jsonBody(list)
        #expect(listBody["pageId"] as? String == "page-1")
        #expect(listBody["cursor"] as? String == "cursor-1")
        #expect(listBody["limit"] as? Int == 20)

        let detail = try Endpoint.pageHistoryInfo(historyId: "history-1").urlRequest(baseURL: baseURL)
        #expect(detail.url?.absoluteString == "https://docs.example.com/api/pages/history/info")
        #expect(try jsonBody(detail)["historyId"] as? String == "history-1")
    }

    @Test func buildsPageExportRequest() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let request = try Endpoint.exportPage(
            pageId: "page-1",
            format: .markdown,
            includeChildren: true,
            includeAttachments: false
        )
        .urlRequest(baseURL: baseURL)

        #expect(request.url?.absoluteString == "https://docs.example.com/api/pages/export")
        let body = try jsonBody(request)
        #expect(body["pageId"] as? String == "page-1")
        #expect(body["format"] as? String == "markdown")
        #expect(body["includeChildren"] as? Bool == true)
        #expect(body["includeAttachments"] as? Bool == false)
    }

    @Test func buildsUpdateCommentRequest() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let endpoint = Endpoint.updateComment(
            commentId: "comment-1",
            content: #"{"type":"doc","content":[]}"#
        )
        let request = try endpoint.urlRequest(baseURL: baseURL)

        #expect(request.url?.absoluteString == "https://docs.example.com/api/comments/update")

        let body = try #require(request.httpBody)
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(object?["commentId"] as? String == "comment-1")
        #expect(object?["content"] as? String == #"{"type":"doc","content":[]}"#)
    }

    @Test func buildsDeleteCommentRequest() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let endpoint = Endpoint.deleteComment(commentId: "comment-1")
        let request = try endpoint.urlRequest(baseURL: baseURL)

        #expect(request.url?.absoluteString == "https://docs.example.com/api/comments/delete")

        let body = try #require(request.httpBody)
        let object = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        #expect(object?["commentId"] as? String == "comment-1")
    }

    private func jsonBody(_ request: URLRequest) throws -> [String: Any] {
        let body = try #require(request.httpBody)
        return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }
}
