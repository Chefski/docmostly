import SwiftUI
import WebKit

struct HTMLPageWebView: UIViewRepresentable {
    let html: String
    let baseURLString: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let document = """
        <!doctype html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <style>
            :root { color-scheme: light dark; }
            body {
              font: -apple-system-body;
              margin: 0;
              color: CanvasText;
              background: transparent;
              line-height: 1.55;
            }
            img, video { max-width: 100%; height: auto; border-radius: 8px; }
            pre {
              overflow-x: auto;
              padding: 12px;
              border-radius: 8px;
              background: rgba(127,127,127,0.14);
            }
            code {
              font: -apple-system-footnote;
              background: rgba(127,127,127,0.14);
              padding: 2px 4px;
              border-radius: 4px;
            }
            blockquote {
              border-left: 4px solid #0b60d8;
              margin-left: 0;
              padding-left: 12px;
              color: color-mix(in srgb, CanvasText 78%, transparent);
            }
            a { color: #0b60d8; }
            table { max-width: 100%; border-collapse: collapse; }
            td, th { border: 1px solid rgba(127,127,127,0.35); padding: 6px; }
          </style>
        </head>
        <body>\(html)</body>
        </html>
        """

        webView.loadHTMLString(document, baseURL: URL(string: baseURLString))
    }
}
