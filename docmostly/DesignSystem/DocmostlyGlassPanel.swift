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
        DocmostlyGlassPanelContent(
            isInteractive: isInteractive,
            shape: shape,
            panelTint: panelTint,
            content: content
        )
    }
}

private struct DocmostlyGlassPanelContent<Content: View>: View {
    let isInteractive: Bool
    let shape: DocmostlyGlassPanelShape
    let panelTint: Color
    let content: Content

    var body: some View {
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
}

private extension DocmostlyGlassPanel {
    var panelTint: Color {
        if colorScheme == .dark {
            .black.opacity(0.24)
        } else {
            .white.opacity(0.34)
        }
    }
}
