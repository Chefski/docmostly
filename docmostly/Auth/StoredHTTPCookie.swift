import Foundation

nonisolated struct StoredHTTPCookie: Codable, Equatable, Sendable {
    let name: String
    let value: String
    let domain: String
    let path: String
    let expiresAt: Date?
    let isSecure: Bool
    let isHTTPOnly: Bool
    let isHostOnly: Bool

    init(
        name: String,
        value: String,
        domain: String,
        path: String,
        expiresAt: Date?,
        isSecure: Bool,
        isHTTPOnly: Bool,
        isHostOnly: Bool = false
    ) {
        self.name = name
        self.value = value
        self.domain = domain
        self.path = path
        self.expiresAt = expiresAt
        self.isSecure = isSecure
        self.isHTTPOnly = isHTTPOnly
        self.isHostOnly = isHostOnly
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case value
        case domain
        case path
        case expiresAt
        case isSecure
        case isHTTPOnly
        case isHostOnly
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        value = try container.decode(String.self, forKey: .value)
        domain = try container.decode(String.self, forKey: .domain)
        path = try container.decode(String.self, forKey: .path)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        isSecure = try container.decode(Bool.self, forKey: .isSecure)
        isHTTPOnly = try container.decode(Bool.self, forKey: .isHTTPOnly)
        isHostOnly = try container.decodeIfPresent(Bool.self, forKey: .isHostOnly) ?? false
    }

    init(cookie: HTTPCookie, isHostOnly: Bool) {
        name = cookie.name
        value = cookie.value
        domain = cookie.domain
        path = cookie.path
        expiresAt = cookie.expiresDate
        isSecure = cookie.isSecure
        isHTTPOnly = cookie.isHTTPOnly
        self.isHostOnly = isHostOnly
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
