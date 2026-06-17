import Foundation
import WebKit

nonisolated enum CookieBridge {
    static func storedCookies(from storage: HTTPCookieStorage = .shared, for baseURL: URL) -> [StoredHTTPCookie] {
        guard let host = baseURL.host else { return [] }
        return (storage.cookies ?? [])
            .filter { cookie in
                let cookieDomain = cookie.domain.hasPrefix(".") ? String(cookie.domain.dropFirst()) : cookie.domain
                return cookieDomain == host || host.hasSuffix(cookieDomain)
            }
            .map(StoredHTTPCookie.init(cookie:))
    }

    static func install(_ cookies: [StoredHTTPCookie], into storage: HTTPCookieStorage = .shared) {
        for storedCookie in cookies {
            guard let cookie = storedCookie.makeCookie() else { continue }
            storage.setCookie(cookie)
        }
    }

    static func clear(_ cookies: [StoredHTTPCookie], from storage: HTTPCookieStorage = .shared) {
        for storedCookie in cookies {
            guard let cookie = storedCookie.makeCookie() else { continue }
            storage.deleteCookie(cookie)
        }
    }

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
}
