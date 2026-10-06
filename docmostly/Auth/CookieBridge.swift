import Foundation
import WebKit

nonisolated enum CookieBridge {
    @MainActor
    static func installInWebKit(_ cookies: [StoredHTTPCookie], store: WKHTTPCookieStore) async {
        for storedCookie in cookies {
            guard let cookie = storedCookie.makeCookie() else { continue }
            await withCheckedContinuation { continuation in
                store.setCookie(cookie) {
                    continuation.resume()
                }
            }
        }
    }

    /// Removes only the cookies the shared persistent WebKit store holds for the Docmost server host.
    /// Older builds seeded this store with session cookies for embeds; unrelated website data is left alone.
    @MainActor
    static func removeWebKitCookies(forHost host: String) async {
        let store = WKWebsiteDataStore.default().httpCookieStore
        for cookie in await store.allCookies() where cookieDomain(cookie.domain, matchesHost: host) {
            await store.deleteCookie(cookie)
        }
    }

    /// True when a cookie stored with `cookieDomain` is sent to `host`, following RFC 6265 domain matching.
    /// A leading dot marks a domain cookie, which also matches subdomains of that domain. A domain without a
    /// leading dot is a host-only cookie, which is only ever sent to exactly that host.
    static func cookieDomain(_ cookieDomain: String, matchesHost host: String) -> Bool {
        let storedDomain = cookieDomain.lowercased()
        let host = host.lowercased()
        let isDomainCookie = storedDomain.hasPrefix(".")
        let domain = String(storedDomain.trimmingPrefix("."))
        guard domain.isEmpty == false, host.isEmpty == false else { return false }
        if isDomainCookie {
            return host == domain || host.hasSuffix("." + domain)
        }
        return host == domain
    }
}
