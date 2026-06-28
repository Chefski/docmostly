import Foundation

actor SessionCookieJar {
    private var storedCookies: [StoredHTTPCookie]

    init(cookies: [StoredHTTPCookie] = []) {
        storedCookies = cookies.filter { $0.isExpired == false }
    }

    func replaceAll(_ cookies: [StoredHTTPCookie]) {
        storedCookies = cookies.filter { $0.isExpired == false }
    }

    func cookies(for url: URL) -> [StoredHTTPCookie] {
        removeExpiredCookies()
        return storedCookies
            .filter { $0.matches(url: url) }
            .sortedForRequestHeader()
    }

    func cookieHeader(for url: URL) -> String? {
        let cookies = cookies(for: url)
        guard cookies.isEmpty == false else { return nil }
        return Self.cookieHeader(from: cookies)
    }

    func ingestCookies(from response: HTTPURLResponse, requestURL: URL) {
        let responseCookies = HTTPCookie.cookies(
            withResponseHeaderFields: Self.headerFields(from: response),
            for: requestURL
        )
        let setCookieHeaders = Self.setCookieHeaderValues(from: response)
        for cookie in responseCookies {
            upsert(StoredHTTPCookie(
                cookie: cookie,
                isHostOnly: Self.isHostOnlyCookie(cookie, setCookieHeaders: setCookieHeaders)
            ))
        }
        removeExpiredCookies()
    }

    func allCookies() -> [StoredHTTPCookie] {
        removeExpiredCookies()
        return storedCookies
    }

    func clear() {
        storedCookies = []
    }

    private func upsert(_ cookie: StoredHTTPCookie) {
        storedCookies.removeAll { $0.hasSameIdentity(as: cookie) }
        if cookie.isExpired == false {
            storedCookies.append(cookie)
        }
    }

    private func removeExpiredCookies() {
        storedCookies.removeAll { $0.isExpired }
    }

    private static func cookieHeader(from cookies: [StoredHTTPCookie]) -> String {
        cookies
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "; ")
    }

    private static func headerFields(from response: HTTPURLResponse) -> [String: String] {
        var headerFields: [String: String] = [:]
        for (key, value) in response.allHeaderFields {
            guard let name = key as? String else { continue }
            if let value = value as? String {
                headerFields[name] = value
            } else {
                headerFields[name] = String(describing: value)
            }
        }
        return headerFields
    }

    private static func setCookieHeaderValues(from response: HTTPURLResponse) -> [String] {
        response.allHeaderFields.compactMap { key, value in
            guard
                let name = key as? String,
                name.caseInsensitiveCompare("Set-Cookie") == .orderedSame
            else {
                return nil
            }
            return value as? String ?? String(describing: value)
        }
    }

    private static func isHostOnlyCookie(_ cookie: HTTPCookie, setCookieHeaders: [String]) -> Bool {
        guard let header = setCookieHeaders.first(where: { header in
            header.lowercased().hasPrefix("\(cookie.name.lowercased())=")
        }) else {
            return true
        }
        return header.range(of: "domain=", options: .caseInsensitive) == nil
    }
}

nonisolated extension Array where Element == StoredHTTPCookie {
    func sortedForRequestHeader() -> [StoredHTTPCookie] {
        sorted { first, second in
            if first.path.count != second.path.count {
                return first.path.count > second.path.count
            }
            return first.name < second.name
        }
    }
}

nonisolated extension StoredHTTPCookie {
    var isExpired: Bool {
        guard let expiresAt else { return false }
        return expiresAt <= Date.now
    }

    func matches(url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        guard matchesScheme(url.scheme) else { return false }
        guard matchesDomain(host) else { return false }
        return matchesPath(url.path)
    }

    func hasSameIdentity(as other: StoredHTTPCookie) -> Bool {
        name == other.name
            && normalizedDomain == other.normalizedDomain
            && normalizedPath == other.normalizedPath
            && isHostOnly == other.isHostOnly
    }

    private var normalizedDomain: String {
        let trimmedDomain = domain.hasPrefix(".") ? String(domain.dropFirst()) : domain
        return trimmedDomain.lowercased()
    }

    private var normalizedPath: String {
        path.isEmpty ? "/" : path
    }

    private func matchesScheme(_ scheme: String?) -> Bool {
        guard isSecure else { return true }
        return scheme == "https" || scheme == "wss"
    }

    private func matchesDomain(_ host: String) -> Bool {
        let cookieDomain = normalizedDomain
        guard isHostOnly == false else {
            return host == cookieDomain
        }
        return host == cookieDomain || host.hasSuffix(".\(cookieDomain)")
    }

    private func matchesPath(_ requestPath: String) -> Bool {
        let cookiePath = normalizedPath
        let path = requestPath.isEmpty ? "/" : requestPath
        guard path.hasPrefix(cookiePath) else { return false }
        if cookiePath == "/" || cookiePath.hasSuffix("/") {
            return true
        }
        guard path.count > cookiePath.count else { return true }
        let boundaryIndex = path.index(path.startIndex, offsetBy: cookiePath.count)
        return path[boundaryIndex] == "/"
    }
}
