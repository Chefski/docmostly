import SwiftUI

struct NativeEditorPageTitleIconTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .blur(radius: phase.isIdentity ? 0 : 8)
            .opacity(phase.isIdentity ? 1 : 0)
    }
}
