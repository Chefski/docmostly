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

    /// True when a cookie scoped to `cookieDomain` is sent to `host` (a leading dot is ignored).
    static func cookieDomain(_ cookieDomain: String, matchesHost host: String) -> Bool {
        let domain = cookieDomain.lowercased().trimmingPrefix(".")
        let host = host.lowercased()
        guard domain.isEmpty == false, host.isEmpty == false else { return false }
        return host == domain || host.hasSuffix("." + domain)
    }
}
