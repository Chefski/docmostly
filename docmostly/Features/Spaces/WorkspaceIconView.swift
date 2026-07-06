import SwiftUI

struct WorkspaceIconView: View {
    @Environment(AppState.self) private var appState

    let logo: String?
    let name: String

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
                        WorkspaceIconFallbackView(initial: initial)
                    @unknown default:
                        WorkspaceIconFallbackView(initial: initial)
                    }
                }
            } else {
                WorkspaceIconFallbackView(initial: initial)
            }
        }
        .frame(width: 28, height: 28)
        .clipShape(.rect(cornerRadius: 8))
        .accessibilityHidden(true)
    }

    private var logoURL: URL? {
        SpaceLogoURL.url(logo: logo, serverURLString: appState.serverURLString)
    }

    private var initial: String {
        String(name.prefix(1)).uppercased()
    }
}
