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
}
