import SwiftUI
import WebKit
import YouTubePlayerKit

struct NativeEditorEmbedBlockView: View {
    let blockID: UUID
    let embed: NativeEditorEmbedBlock
    let actions: NativeEditorRichBlockEditingActions?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let youtubeSource = embed.youtubePlayerSource {
                NativeEditorYouTubeEmbedView(source: youtubeSource)
                    .id(youtubeSource)
            } else if let spotifyURL = embed.spotifyEmbedURL {
                NativeEditorSpotifyEmbedView(url: spotifyURL)
            } else {
                NativeEditorGenericEmbedView(embed: embed)
            }

            if let actions {
                NativeEditorEmbedEditor(blockID: blockID, embed: embed, actions: actions)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }
}

private struct NativeEditorYouTubeEmbedView: View {
    let source: String
    @State private var player: YouTubePlayer

    init(source: String) {
        self.source = source
        self._player = State(initialValue: YouTubePlayer(urlString: source))
    }

    var body: some View {
        YouTubePlayerView(player) { state in
            switch state {
            case .idle:
                ProgressView()
                    .controlSize(.small)
            case .ready:
                EmptyView()
            case .error:
                Label("Unable to load YouTube video", systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minHeight: 220)
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary, lineWidth: 1)
        }
        .accessibilityLabel("YouTube player")
    }
}

private struct NativeEditorSpotifyEmbedView: View {
    let url: URL

    var body: some View {
        NativeEditorWebEmbedView(
            html: NativeEditorWebEmbedHTML.iframeHTML(source: url, title: "Spotify embed"),
            allowedHosts: ["open.spotify.com"]
        )
        .frame(minHeight: 180)
        .clipShape(.rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary, lineWidth: 1)
        }
        .accessibilityLabel("Spotify player")
    }
}

private struct NativeEditorGenericEmbedView: View {
    let embed: NativeEditorEmbedBlock

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "rectangle.connected.to.line.below")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.secondary)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(embed.displayProvider)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let sourceURL {
                    Link(sourceURL.absoluteString, destination: sourceURL)
                        .font(.subheadline)
                        .lineLimit(3)
                } else if let source = embed.source, source.isEmpty == false {
                    Text(source)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.18), in: .rect(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.quaternary, lineWidth: 1)
        }
        .glassEffect(.regular.tint(.white.opacity(0.08)), in: .rect(cornerRadius: 10))
    }

    private var sourceURL: URL? {
        NativeEditorWebURLPolicy.webURL(from: embed.source)
    }
}

enum NativeEditorWebEmbedHTML {
    static func iframeHTML(source: URL, title: String) -> String {
        let escapedSource = escapedAttribute(source.absoluteString)
        let escapedTitle = escapedAttribute(title)
        return """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        html, body, iframe {
            border: 0;
            height: 100%;
            margin: 0;
            padding: 0;
            width: 100%;
        }
        body {
            background: transparent;
            overflow: hidden;
        }
        </style>
        </head>
        <body>
        <iframe
            src="\(escapedSource)"
            title="\(escapedTitle)"
            allow="autoplay; clipboard-write; encrypted-media; fullscreen; picture-in-picture"
            loading="lazy">
        </iframe>
        </body>
        </html>
        """
    }

    static func imageHTML(source: URL, title: String) -> String {
        """
        <!doctype html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        html, body {
            background: transparent;
            height: 100%;
            margin: 0;
            overflow: hidden;
            padding: 0;
            width: 100%;
        }
        body {
            align-items: center;
            display: flex;
            justify-content: center;
        }
        img {
            border-radius: 8px;
            display: block;
            height: auto;
            max-height: 100%;
            max-width: 100%;
            width: auto;
        }
        </style>
        </head>
        <body>
        <img src="\(escapedAttribute(source.absoluteString))" alt="\(escapedAttribute(title))">
        </body>
        </html>
        """
    }

    private static func escapedAttribute(_ value: String) -> String {
        value
            .replacing("&", with: "&amp;")
            .replacing("\"", with: "&quot;")
            .replacing("<", with: "&lt;")
            .replacing(">", with: "&gt;")
    }
}

#if os(iOS)
struct NativeEditorWebEmbedView: UIViewRepresentable {
    let html: String
    let allowedHosts: Set<String>
    var cookies: [StoredHTTPCookie] = []

    func makeCoordinator() -> NativeEditorWebEmbedCoordinator {
        NativeEditorWebEmbedCoordinator(allowedHosts: allowedHosts)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.allowedHosts = allowedHosts
        context.coordinator.load(html: html, cookies: cookies, in: webView)
    }
}
#elseif os(macOS)
struct NativeEditorWebEmbedView: NSViewRepresentable {
    let html: String
    let allowedHosts: Set<String>
    var cookies: [StoredHTTPCookie] = []

    func makeCoordinator() -> NativeEditorWebEmbedCoordinator {
        NativeEditorWebEmbedCoordinator(allowedHosts: allowedHosts)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.allowedHosts = allowedHosts
        context.coordinator.load(html: html, cookies: cookies, in: webView)
    }
}
#endif

final class NativeEditorWebEmbedCoordinator: NSObject, WKNavigationDelegate {
    var allowedHosts: Set<String>
    private var loadedHTML: String?
    private var loadedCookies: [StoredHTTPCookie] = []
    private var loadTask: Task<Void, Never>?

    init(allowedHosts: Set<String>) {
        self.allowedHosts = allowedHosts
        super.init()
    }

    func load(html: String, cookies: [StoredHTTPCookie], in webView: WKWebView) {
        guard loadedHTML != html || loadedCookies != cookies else { return }
        loadedHTML = html
        loadedCookies = cookies
        loadTask?.cancel()
        loadTask = Task { @MainActor [weak webView] in
            guard let webView else { return }
            await CookieBridge.installInWebKit(
                cookies,
                store: webView.configuration.websiteDataStore.httpCookieStore
            )
            guard Task.isCancelled == false else { return }
            webView.loadHTMLString(html, baseURL: nil)
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction
    ) async -> WKNavigationActionPolicy {
        let isAllowed = NativeEditorWebURLPolicy.allowsNavigation(
            to: navigationAction.request.url,
            allowedHosts: allowedHosts
        )
        return isAllowed ? .allow : .cancel
    }
}
