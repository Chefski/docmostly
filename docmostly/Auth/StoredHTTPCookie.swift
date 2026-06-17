import Foundation

nonisolated struct StoredHTTPCookie: Codable, Equatable, Sendable {
    let name: String
    let value: String
    let domain: String
    let path: String
    let expiresAt: Date?
    let isSecure: Bool
    let isHTTPOnly: Bool

    init(
        name: String,
        value: String,
        domain: String,
        path: String,
        expiresAt: Date?,
        isSecure: Bool,
        isHTTPOnly: Bool
    ) {
        self.name = name
        self.value = value
        self.domain = domain
        self.path = path
        self.expiresAt = expiresAt
        self.isSecure = isSecure
        self.isHTTPOnly = isHTTPOnly
    }

    init(cookie: HTTPCookie) {
        name = cookie.name
        value = cookie.value
        domain = cookie.domain
        path = cookie.path
        expiresAt = cookie.expiresDate
        isSecure = cookie.isSecure
        isHTTPOnly = cookie.isHTTPOnly
    }

    func makeCookie() -> HTTPCookie? {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name,
            .value: value,
            .domain: domain,
            .path: path,
            .secure: isSecure ? "TRUE" : "FALSE"
        ]

        if let expiresAt {
            properties[.expires] = expiresAt
        }

        if isHTTPOnly {
            properties[HTTPCookiePropertyKey("HttpOnly")] = "TRUE"
        }

        return HTTPCookie(properties: properties)
    }
}
