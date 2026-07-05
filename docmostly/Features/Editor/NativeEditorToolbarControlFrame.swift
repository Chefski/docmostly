import SwiftUI

private struct NativeEditorToolbarControlFrame: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(
                width: NativeEditorToolbarMetrics.controlSideLength,
                height: NativeEditorToolbarMetrics.controlSideLength
            )
            .contentShape(.capsule)
    }
}

extension View {
    func nativeEditorToolbarControlFrame() -> some View {
        modifier(NativeEditorToolbarControlFrame())
    }
}
