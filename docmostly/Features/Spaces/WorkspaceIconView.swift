import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct WorkspaceIconView: View {
    @Environment(AppState.self) private var appState
    @State private var imageData: Data?
    @State private var didFailImageLoad = false

    let logo: String?
    let name: String
    let size: CGFloat

    var body: some View {
        Group {
            if let logoURL {
                loadedImageContent(logoURL: logoURL)
            } else {
                WorkspaceIconFallbackView(initial: initial)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
        .task(id: logoURL) {
            await loadLogoImage(from: logoURL)
        }
    }

    init(logo: String?, name: String, size: CGFloat = 28) {
        self.logo = logo
        self.name = name
        self.size = size
    }

    private var logoURL: URL? {
        SpaceLogoURL.url(
            logo: logo,
            serverURLString: appState.serverURLString,
            type: .workspaceIcon
        )
    }

    private var initial: String {
        String(name.prefix(1)).uppercased()
    }

    @ViewBuilder
    private func loadedImageContent(logoURL: URL) -> some View {
        if let imageData, let image = PlatformImage(data: imageData), didFailImageLoad == false {
            Image(platformImage: image)
                .resizable()
                .scaledToFill()
        } else {
            WorkspaceIconFallbackView(initial: initial)
        }
    }

    private func loadLogoImage(from url: URL?) async {
        imageData = nil
        didFailImageLoad = false
        guard let url else { return }

        var request = URLRequest(url: url)
        request.httpShouldHandleCookies = false

        let cookies = await appState.activeSessionCookies(for: url)
        if cookies.isEmpty == false {
            request.setValue(cookieHeader(from: cookies), forHTTPHeaderField: "Cookie")
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard
                let httpResponse = response as? HTTPURLResponse,
                200..<300 ~= httpResponse.statusCode
            else {
                didFailImageLoad = true
                return
            }

            imageData = data
        } catch {
            didFailImageLoad = true
        }
    }

    private func cookieHeader(from cookies: [StoredHTTPCookie]) -> String {
        cookies
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "; ")
    }
}

#if os(macOS)
private typealias PlatformImage = NSImage

private extension Image {
    init(platformImage: PlatformImage) {
        self.init(nsImage: platformImage)
    }
}
#else
private typealias PlatformImage = UIImage

private extension Image {
    init(platformImage: PlatformImage) {
        self.init(uiImage: platformImage)
    }
}
#endif
