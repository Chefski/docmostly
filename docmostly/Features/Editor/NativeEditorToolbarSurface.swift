import SwiftUI

struct NativeEditorToolbarSurface<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        DocmostlyGlassPanel(
            shape: .capsule,
            isInteractive: true
        ) {
            NativeEditorToolbarSurfaceContent(content: content)
        }
    }
}

private struct NativeEditorToolbarSurfaceContent<Content: View>: View {
    let content: Content

    var body: some View {
        HStack(spacing: NativeEditorToolbarMetrics.controlSpacing) {
            content
        }
        .frame(height: NativeEditorToolbarMetrics.controlSideLength)
        .padding(.horizontal, NativeEditorToolbarMetrics.horizontalPadding)
        .padding(.vertical, NativeEditorToolbarMetrics.verticalPadding)
    }
}
