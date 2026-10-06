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

    /// Clears the shared persistent WebKit store, which older builds used for embeds and seeded with session cookies.
    @MainActor
    static func removeAllWebKitData() async {
        await WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        )
    }
}
