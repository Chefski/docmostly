import Foundation
import Testing
@testable import docmostly

struct AuthServiceCookieTests {
    @Test func restoreSessionSeedsCookieJar() async throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let store = InMemorySessionStore()
        let jar = SessionCookieJar()
        try await store.save(StoredSession(serverBaseURL: baseURL, cookies: [
            cookie(name: "authToken", value: "restored", domain: "docs.example.com", path: "/")
        ]))
        let service = AuthService(sessionStore: store, cookieJar: jar)

        _ = try await service.restoreSession()
        let header = await jar.cookieHeader(for: baseURL.appending(path: "api/users/me"))

        #expect(header == "authToken=restored")
    }

    @Test func loginPersistsCookiesFromJarAfterCurrentUserLoads() async throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let store = InMemorySessionStore()
        let jar = SessionCookieJar()
        let loader = CapturingHTTPDataLoader(responses: [
            try loaderResponse(
                url: baseURL.appending(path: "api/auth/login"),
                headerFields: [
                    "Set-Cookie": "authToken=login-token; Path=/; HttpOnly; Secure"
                ]
            ),
            try loaderResponse(
                url: baseURL.appending(path: "api/users/me"),
                data: currentUserEnvelopeData(),
                headerFields: [
                    "Set-Cookie": "refreshToken=current-user-token; Path=/; HttpOnly; Secure"
                ]
            )
        ])
        let client = DocmostAPIClient(baseURL: baseURL, loader: loader, cookieJar: jar)
        let service = AuthService(sessionStore: store, cookieJar: jar)

        _ = try await service.login(
            credentials: AuthCredentials(email: "chef@example.com", password: "secret"),
            client: client
        )
        let restoredSession = try await store.load()
        let session = try #require(restoredSession)

        #expect(session.cookies.map(\.name).sorted() == ["authToken", "refreshToken"])
    }

    @Test func logoutClearsCookieJarAndStoredSession() async throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))
        let store = InMemorySessionStore()
        let jar = SessionCookieJar(cookies: [
            cookie(name: "authToken", value: "secret", domain: "docs.example.com", path: "/")
        ])
        try await store.save(StoredSession(serverBaseURL: baseURL, cookies: [
            cookie(name: "authToken", value: "secret", domain: "docs.example.com", path: "/")
        ]))
        let loader = CapturingHTTPDataLoader(responses: [
            try loaderResponse(url: baseURL.appending(path: "api/auth/logout"))
        ])
        let client = DocmostAPIClient(baseURL: baseURL, loader: loader, cookieJar: jar)
        let service = AuthService(sessionStore: store, cookieJar: jar)

        try await service.logout(client: client)

        let cookies = await jar.allCookies()
        let storedSession = try await store.load()
        #expect(cookies.isEmpty)
        #expect(storedSession == nil)
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
        try #require("""
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
        """.data(using: .utf8))
    }
}
