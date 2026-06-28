import Foundation

actor SessionCookieJar {
    private var storedCookies: [StoredHTTPCookie]
    private static let cookieMonthNumbers = [
        "jan": 1,
        "feb": 2,
        "mar": 3,
        "apr": 4,
        "may": 5,
        "jun": 6,
        "jul": 7,
        "aug": 8,
        "sep": 9,
        "oct": 10,
        "nov": 11,
        "dec": 12
    ]

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
        for header in setCookieHeaders {
            removeDeletedCookie(from: header, requestURL: requestURL)
        }
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

    private func removeDeletedCookie(from header: String, requestURL: URL) {
        let parts = header
            .split(separator: ";", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard
            let nameValue = parts.first,
            let separatorIndex = nameValue.firstIndex(of: "=")
        else {
            return
        }

        let name = String(nameValue[..<separatorIndex])
        guard name.isEmpty == false else { return }

        var domain = requestURL.host?.lowercased() ?? ""
        var path = Self.defaultCookiePath(for: requestURL)
        var isHostOnly = true
        var deletesCookie = false

        for attribute in parts.dropFirst() {
            let keyValue = attribute.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            let key = keyValue.first?.lowercased() ?? ""
            let value = keyValue.count > 1 ? String(keyValue[1]) : ""

            switch key {
            case "domain":
                domain = value.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased()
                isHostOnly = false
            case "path":
                path = value.isEmpty ? "/" : value
            case "max-age":
                if let seconds = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    deletesCookie = deletesCookie || seconds <= 0
                }
            case "expires":
                deletesCookie = deletesCookie || Self.isExpiredCookieDate(value)
            default:
                continue
            }
        }

        guard deletesCookie else { return }

        let expiredCookie = StoredHTTPCookie(
            name: name,
            value: value,
            domain: domain,
            path: path,
            expiresAt: .distantPast,
            isSecure: false,
            isHTTPOnly: false,
            isHostOnly: isHostOnly
        )
        storedCookies.removeAll { $0.hasSameIdentity(as: expiredCookie) }
    }

    private static func defaultCookiePath(for requestURL: URL) -> String {
        let requestPath = requestURL.path
        guard requestPath.hasPrefix("/"), requestPath != "/" else { return "/" }
        guard let lastSlashIndex = requestPath.lastIndex(of: "/"), lastSlashIndex != requestPath.startIndex else {
            return "/"
        }
        return String(requestPath[..<lastSlashIndex])
    }

    private static func isExpiredCookieDate(_ value: String) -> Bool {
        guard let date = cookieDate(from: value) else { return false }
        return date <= Date.now
    }

    private static func cookieDate(from value: String) -> Date? {
        let parts = value
            .replacing(",", with: " ")
            .split(separator: " ")
            .map(String.init)
        let offset = parts.first.flatMap { Int($0) } == nil ? 1 : 0
        guard parts.count >= offset + 4,
              let day = Int(parts[offset]),
              let month = monthNumber(parts[offset + 1]),
              let year = Int(parts[offset + 2])
        else {
            return nil
        }

        let timeParts = parts[offset + 3].split(separator: ":")
        guard timeParts.count == 3,
              let hour = Int(timeParts[0]),
              let minute = Int(timeParts[1]),
              let second = Int(timeParts[2])
        else {
            return nil
        }

        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return components.date
    }

    private static func monthNumber(_ value: String) -> Int? {
        cookieMonthNumbers[value.lowercased()]
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
