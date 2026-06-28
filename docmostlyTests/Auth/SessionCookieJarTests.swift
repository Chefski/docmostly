import Foundation
import Testing
@testable import docmostly

struct SessionCookieJarTests {
    @Test func filtersCookiesByDomainPathSchemeAndExpiry() async throws {
        let jar = SessionCookieJar(cookies: [
            cookie(name: "root", value: "root-value", domain: ".example.com", path: "/", isSecure: true),
            cookie(name: "docs", value: "docs-value", domain: "docs.example.com", path: "/docs"),
            cookie(name: "other", value: "other-value", domain: "other.example.com", path: "/"),
            cookie(
                name: "expired",
                value: "expired-value",
                domain: ".example.com",
                path: "/",
                expiresAt: Date.now.addingTimeInterval(-60)
            )
        ])
        let secureURL = try #require(URL(string: "https://docs.example.com/docs/page"))
        let insecureURL = try #require(URL(string: "http://docs.example.com/docs/page"))
        let wrongPathURL = try #require(URL(string: "https://docs.example.com/docsets/page"))

        let secureHeader = await jar.cookieHeader(for: secureURL)
        let insecureHeader = await jar.cookieHeader(for: insecureURL)
        let wrongPathCookies = await jar.cookies(for: wrongPathURL)
        let remainingCookies = await jar.allCookies()

        #expect(secureHeader == "docs=docs-value; root=root-value")
        #expect(insecureHeader == "docs=docs-value")
        #expect(wrongPathCookies.map(\.name) == ["root"])
        #expect(remainingCookies.map(\.name).contains("expired") == false)
    }

    @Test func rejectsHostSuffixesThatAreNotDomainBoundaries() async throws {
        let jar = SessionCookieJar(cookies: [
            cookie(name: "auth", value: "secret", domain: "example.com", path: "/")
        ])
        let lookalikeURL = try #require(URL(string: "https://badexample.com/api/users/me"))

        let cookies = await jar.cookies(for: lookalikeURL)

        #expect(cookies.isEmpty)
    }

    @Test func hostOnlyCookiesDoNotMatchSubdomains() async throws {
        let jar = SessionCookieJar(cookies: [
            cookie(name: "host", value: "host-value", domain: "docs.example.com", path: "/", isHostOnly: true),
            cookie(name: "domain", value: "domain-value", domain: "example.com", path: "/", isHostOnly: false)
        ])
        let subdomainURL = try #require(URL(string: "https://api.docs.example.com/api/users/me"))
        let siblingURL = try #require(URL(string: "https://api.example.com/api/users/me"))

        let subdomainCookies = await jar.cookies(for: subdomainURL)
        let siblingHeader = await jar.cookieHeader(for: siblingURL)

        #expect(subdomainCookies.map(\.name) == ["domain"])
        #expect(siblingHeader == "domain=domain-value")
    }

    @Test func replaceAndClearControlTheStoredCookieSet() async throws {
        let jar = SessionCookieJar(cookies: [
            cookie(name: "old", value: "old-value", domain: "docs.example.com", path: "/")
        ])

        await jar.replaceAll([
            cookie(name: "new", value: "new-value", domain: "docs.example.com", path: "/")
        ])
        let replacedCookies = await jar.allCookies()

        await jar.clear()
        let clearedCookies = await jar.allCookies()

        #expect(replacedCookies.map(\.name) == ["new"])
        #expect(clearedCookies.isEmpty)
    }

    @Test func ingestsSetCookieHeadersAndRemovesExpiredCookies() async throws {
        let requestURL = try #require(URL(string: "https://docs.example.com/api/auth/login"))
        let jar = SessionCookieJar(cookies: [
            cookie(name: "authToken", value: "old", domain: "docs.example.com", path: "/")
        ])
        let loginResponse = try httpResponse(
            url: requestURL,
            headerFields: [
                "Set-Cookie": "authToken=rotated; Path=/; HttpOnly; Secure"
            ]
        )
        await jar.ingestCookies(from: loginResponse, requestURL: requestURL)

        let rotatedHeader = await jar.cookieHeader(for: requestURL)
        let logoutResponse = try httpResponse(
            url: requestURL,
            headerFields: [
                "Set-Cookie": "authToken=; Path=/; Expires=Thu, 01 Jan 1970 00:00:00 GMT"
            ]
        )
        await jar.ingestCookies(from: logoutResponse, requestURL: requestURL)
        let clearedCookies = await jar.allCookies()

        #expect(rotatedHeader == "authToken=rotated")
        #expect(clearedCookies.isEmpty)
    }

    @Test func maxAgeTombstoneDeletesNonEmptyCookieWithDefaultPath() async throws {
        let requestURL = try #require(URL(string: "https://docs.example.com/api/auth/logout"))
        let jar = SessionCookieJar(cookies: [
            cookie(name: "authToken", value: "old", domain: "docs.example.com", path: "/api/auth")
        ])
        let logoutResponse = try httpResponse(
            url: requestURL,
            headerFields: [
                "Set-Cookie": "authToken=deleted; Max-Age=0; HttpOnly; Secure"
            ]
        )

        await jar.ingestCookies(from: logoutResponse, requestURL: requestURL)
        let clearedCookies = await jar.allCookies()

        #expect(clearedCookies.isEmpty)
    }

    @Test func expiredSetCookieDateDeletesMatchingCookie() async throws {
        let requestURL = try #require(URL(string: "https://docs.example.com/api/auth/logout"))
        let jar = SessionCookieJar(cookies: [
            cookie(name: "authToken", value: "old", domain: "docs.example.com", path: "/api/auth")
        ])
        let logoutResponse = try httpResponse(
            url: requestURL,
            headerFields: [
                "Set-Cookie": "authToken=deleted; Path=/api/auth; Expires=Wed, 21 Oct 2015 07:28:00 GMT"
            ]
        )

        await jar.ingestCookies(from: logoutResponse, requestURL: requestURL)
        let clearedCookies = await jar.allCookies()

        #expect(clearedCookies.isEmpty)
    }

    private func cookie(
        name: String,
        value: String,
        domain: String,
        path: String,
        expiresAt: Date? = nil,
        isSecure: Bool = false,
        isHTTPOnly: Bool = true,
        isHostOnly: Bool = false
    ) -> StoredHTTPCookie {
        StoredHTTPCookie(
            name: name,
            value: value,
            domain: domain,
            path: path,
            expiresAt: expiresAt,
            isSecure: isSecure,
            isHTTPOnly: isHTTPOnly,
            isHostOnly: isHostOnly
        )
    }

    private func httpResponse(url: URL, headerFields: [String: String]) throws -> HTTPURLResponse {
        try #require(HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: headerFields
        ))
    }
}
