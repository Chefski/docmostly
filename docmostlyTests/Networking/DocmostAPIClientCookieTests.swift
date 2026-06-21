import Foundation
import Testing
@testable import docmostly

struct DocmostAPIClientCookieTests {
    @Test func sendsRestoredCookiesAsExplicitHeaders() async throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let jar = SessionCookieJar(cookies: [
            cookie(name: "authToken", value: "secret", domain: "docs.example.com", path: "/")
        ])
        let loader = CapturingHTTPDataLoader(responses: [
            try loaderResponse(
                url: baseURL.appending(path: "api/users/me"),
                data: currentUserEnvelopeData()
            )
        ])
        let client = DocmostAPIClient(baseURL: baseURL, loader: loader, cookieJar: jar)

        let _: CurrentUserResponse = try await client.send(.currentUser)
        let dataRequests = await loader.dataRequests
        let request = try #require(dataRequests.first)

        #expect(request.value(forHTTPHeaderField: "Cookie") == "authToken=secret")
        #expect(request.httpShouldHandleCookies == false)
    }

    @Test func updatesCookieJarFromResponseHeaders() async throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let jar = SessionCookieJar()
        let loader = CapturingHTTPDataLoader(responses: [
            try loaderResponse(
                url: baseURL.appending(path: "api/auth/login"),
                headerFields: [
                    "Set-Cookie": "authToken=rotated; Path=/; HttpOnly; Secure"
                ]
            )
        ])
        let client = DocmostAPIClient(baseURL: baseURL, loader: loader, cookieJar: jar)

        try await client.sendVoid(.login(email: "chef@example.com", password: "secret"))
        let header = await jar.cookieHeader(for: baseURL.appending(path: "api/users/me"))

        #expect(header == "authToken=rotated")
    }

    @Test func uploadRequestsUseExplicitCookieHeaders() async throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let sourceURL = URL.temporaryDirectory.appending(path: "docmostly-cookie-upload.txt")
        try "upload".write(to: sourceURL, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
        }
        let jar = SessionCookieJar(cookies: [
            cookie(name: "authToken", value: "secret", domain: "docs.example.com", path: "/")
        ])
        let loader = CapturingHTTPDataLoader(responses: [
            try loaderResponse(
                url: baseURL.appending(path: "api/files/upload"),
                data: attachmentData()
            )
        ])
        let client = DocmostAPIClient(baseURL: baseURL, loader: loader, cookieJar: jar)

        _ = try await client.uploadFile(fileURL: sourceURL, pageId: "page-1")
        let uploadRequests = await loader.uploadRequests
        let request = try #require(uploadRequests.first)

        #expect(request.value(forHTTPHeaderField: "Cookie") == "authToken=secret")
        #expect(request.httpShouldHandleCookies == false)
    }

    @Test func redirectPolicyRejectsCrossOriginRedirects() throws {
        let original = try #require(URL(string: "https://docs.example.com/api/users/me"))
        let redirect = try #require(URL(string: "https://evil.example.net/capture"))

        #expect(DocmostURLSessionFactory.isRedirectAllowed(from: original, to: redirect) == false)
    }

    @Test func redirectPolicyAllowsSameOriginRedirectsWithDefaultPorts() throws {
        let original = try #require(URL(string: "https://docs.example.com:443/api/users/me"))
        let redirect = try #require(URL(string: "https://docs.example.com/maintenance"))

        #expect(DocmostURLSessionFactory.isRedirectAllowed(from: original, to: redirect) == true)
    }

    private func cookie(name: String, value: String, domain: String, path: String) -> StoredHTTPCookie {
        StoredHTTPCookie(
            name: name,
            value: value,
            domain: domain,
            path: path,
            expiresAt: nil,
            isSecure: true,
            isHTTPOnly: true
        )
    }

    private func loaderResponse(
        url: URL,
        data: Data = Data(),
        headerFields: [String: String] = [:]
    ) throws -> CapturingHTTPDataLoader.Response {
        let response = try #require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: headerFields
        ))
        return CapturingHTTPDataLoader.Response(data: data, response: response)
    }

    private func currentUserEnvelopeData() throws -> Data {
        Data("""
        {
          "data": {
            "user": {
              "id": "user-1",
              "name": "Chef"
            },
            "workspace": {
              "id": "workspace-1",
              "name": "Docs"
            }
          },
          "success": true,
          "status": 200
        }
        """.utf8)
    }

    private func attachmentData() throws -> Data {
        Data("""
        {
          "id": "attachment-1",
          "fileName": "docmostly-cookie-upload.txt"
        }
        """.utf8)
    }
}

actor CapturingHTTPDataLoader: HTTPDataLoading {
    struct Response {
        let data: Data
        let response: HTTPURLResponse
    }

    private var responses: [Response]
    private(set) var dataRequests: [URLRequest] = []
    private(set) var uploadRequests: [URLRequest] = []

    init(responses: [Response]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        dataRequests.append(request)
        return try nextResponse()
    }

    func upload(for request: URLRequest, fromFile fileURL: URL) async throws -> (Data, URLResponse) {
        uploadRequests.append(request)
        return try nextResponse()
    }

    private func nextResponse() throws -> (Data, URLResponse) {
        guard responses.isEmpty == false else {
            throw APIError.connectionFailed("Missing test response.")
        }
        let response = responses.removeFirst()
        return (response.data, response.response)
    }
}
