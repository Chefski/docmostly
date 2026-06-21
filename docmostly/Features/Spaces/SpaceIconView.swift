import SwiftUI

struct SpaceIconView: View {
    @Environment(AppState.self) private var appState

    let space: DocmostSpace

    var body: some View {
        Group {
            if let logoURL {
                AsyncImage(url: logoURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .empty, .failure:
                        SpaceIconFallbackView(initial: initial)
                    @unknown default:
                        SpaceIconFallbackView(initial: initial)
                    }
                }
            } else {
                SpaceIconFallbackView(initial: initial)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(.rect(cornerRadius: 6))
        .accessibilityHidden(true)
    }

    private var logoURL: URL? {
        SpaceLogoURL.url(logo: space.logo, serverURLString: appState.serverURLString)
    }

    private var initial: String {
        String(space.name.prefix(1)).uppercased()
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
