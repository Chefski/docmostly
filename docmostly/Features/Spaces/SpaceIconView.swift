import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct SpaceIconView: View {
    @Environment(AppState.self) private var appState
    @State private var imageData: Data?

    let space: DocmostSpace
    let size: CGFloat

    var body: some View {
        Group {
            if logoURL != nil {
                loadedImageContent()
            } else {
                SpaceIconFallbackView(initial: initial)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .accessibilityHidden(true)
        .task(id: logoURL) {
            await loadLogoImage(from: logoURL)
        }
    }

    init(space: DocmostSpace, size: CGFloat = 28) {
        self.space = space
        self.size = size
    }

    private var logoURL: URL? {
        SpaceLogoURL.url(logo: space.logo, serverURLString: appState.serverURLString)
    }

    private var initial: String {
        String(space.name.prefix(1)).uppercased()
    }

    @ViewBuilder
    private func loadedImageContent() -> some View {
        if let imageData, let image = SpaceIconPlatformImage(data: imageData) {
            Image(spaceIconPlatformImage: image)
                .resizable()
                .scaledToFill()
        } else {
            SpaceIconFallbackView(initial: initial)
        }
    }

    private func loadLogoImage(from url: URL?) async {
        imageData = nil
        guard let url else { return }

        do {
            let data = try await appState.loadAuthenticatedImageData(from: url)
            guard SpaceIconPlatformImage(data: data) != nil else { return }

            guard Task.isCancelled == false else { return }
            imageData = data
        } catch {
            return
        }
    }
}

private struct SpaceIconFallbackView: View {
    let initial: String

    var body: some View {
        ZStack {
            DocmostlyTheme.primary.opacity(0.12)
            Text(initial)
                .font(.caption)
                .bold()
                .foregroundStyle(DocmostlyTheme.primary)
        }
    }
}

#if os(macOS)
private typealias SpaceIconPlatformImage = NSImage

private extension Image {
    init(spaceIconPlatformImage: SpaceIconPlatformImage) {
        self.init(nsImage: spaceIconPlatformImage)
    }
}
#else
private typealias SpaceIconPlatformImage = UIImage

private extension Image {
    init(spaceIconPlatformImage: SpaceIconPlatformImage) {
        self.init(uiImage: spaceIconPlatformImage)
    }
}
#endif
