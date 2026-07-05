import SwiftUI

enum DocmostlyGlassPanelShape {
    case roundedRectangle(cornerRadius: CGFloat)
    case capsule
}

struct DocmostlyGlassPanel<Content: View>: View {
    let isInteractive: Bool
    let shape: DocmostlyGlassPanelShape
    let content: Content
    @Environment(\.colorScheme) private var colorScheme

    init(
        cornerRadius: CGFloat = 18,
        isInteractive: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.isInteractive = isInteractive
        self.shape = .roundedRectangle(cornerRadius: cornerRadius)
        self.content = content()
    }

    init(
        shape: DocmostlyGlassPanelShape,
        isInteractive: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.isInteractive = isInteractive
        self.shape = shape
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            liquidGlassContent
        } else {
            fallbackContent
        }
    }

    @available(iOS 26.0, macOS 26.0, *)
    @ViewBuilder
    private var liquidGlassContent: some View {
        switch shape {
        case .capsule:
            if isInteractive {
                content
                    .glassEffect(.regular.tint(panelTint).interactive(), in: .capsule)
            } else {
                content
                    .glassEffect(.regular.tint(panelTint), in: .capsule)
            }
        case .roundedRectangle(let cornerRadius):
            if isInteractive {
                content
                    .glassEffect(.regular.tint(panelTint).interactive(), in: .rect(cornerRadius: cornerRadius))
            } else {
                content
                    .glassEffect(.regular.tint(panelTint), in: .rect(cornerRadius: cornerRadius))
            }
        }
    }

    @ViewBuilder
    private var fallbackContent: some View {
        switch shape {
        case .capsule:
            content
                .background(.regularMaterial, in: .capsule)
                .background(panelTint, in: .capsule)
                .overlay {
                    Capsule()
                        .stroke(.quaternary)
                }
                .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
        case .roundedRectangle(let cornerRadius):
            content
                .background(.regularMaterial, in: .rect(cornerRadius: cornerRadius))
                .background(panelTint, in: .rect(cornerRadius: cornerRadius))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(.quaternary)
                }
                .shadow(color: .black.opacity(0.10), radius: 12, y: 4)
        }
    }

    private var panelTint: Color {
        if colorScheme == .dark {
            .black.opacity(0.24)
        } else {
            .white.opacity(0.34)
        }
    }
}
