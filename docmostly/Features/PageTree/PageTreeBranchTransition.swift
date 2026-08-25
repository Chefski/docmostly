import SwiftUI

struct PageTreeBranchTransition: Transition {
    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .blur(radius: phase.isIdentity ? 0 : 8)
            .offset(y: phase.isIdentity ? 0 : -(PageTreeSidebarMetrics.rowHeight / 2))
    }
}
