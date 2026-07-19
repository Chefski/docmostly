import SwiftUI

struct NativeEditorImageBlockView: View {
    let blockID: UUID
    let media: NativeEditorMediaBlock
    let serverURLString: String?
    let actions: NativeEditorRichBlockEditingActions?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Group {
                if let sourceURL {
                    AsyncImage(url: sourceURL) { phase in
                        switch phase {
                        case .empty:
                            ProgressView("Loading image")
                                .frame(maxWidth: .infinity, minHeight: 120)
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            unavailableImage
                        @unknown default:
                            unavailableImage
                        }
                    }
                    .containerRelativeFrame(.horizontal) { length, _ in
                        resolvedWidth(containerWidth: length)
                    }
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
                    .clipShape(.rect(cornerRadius: 8))
                } else {
                    unavailableImage
                }
            }
            .frame(maxWidth: .infinity, alignment: frameAlignment)

            if let actions {
                NativeEditorMediaBlockEditor(blockID: blockID, media: media, actions: actions)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(media.alternativeText ?? "Image")
    }

    private var unavailableImage: some View {
        Label("Image unavailable", systemImage: "photo")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(.quaternary.opacity(0.12), in: .rect(cornerRadius: 8))
    }

    private var sourceURL: URL? {
        NativeEditorWebURLPolicy.documentResourceURL(
            from: media.source,
            serverURLString: serverURLString
        )
    }

    private var frameAlignment: Alignment {
        switch media.alignment {
        case "left": .leading
        case "right": .trailing
        default: .center
        }
    }

    private func resolvedWidth(containerWidth: CGFloat) -> CGFloat {
        guard let width = media.width?.trimmingCharacters(in: .whitespacesAndNewlines), width.isEmpty == false else {
            return containerWidth
        }
        if width.hasSuffix("%"), let percentage = Double(width.dropLast()) {
            return containerWidth * CGFloat(min(max(percentage, 1), 100) / 100)
        }
        if let pixels = Double(width) {
            return min(containerWidth, CGFloat(max(pixels, 44)))
        }
        return containerWidth
    }
}
