import SwiftUI
import WebKit

struct DocmostEditorWebView: UIViewRepresentable {
    let url: URL
    let appState: AppState

    func makeUIView(context: Context) -> WKWebView {
        WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        Task { @MainActor in
            let cookies = await appState.storedSessionCookies()
            await CookieBridge.installInWebKit(cookies, store: webView.configuration.websiteDataStore.httpCookieStore)
            webView.load(URLRequest(url: url))
        }
    }
}
