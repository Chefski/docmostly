import SwiftUI

@MainActor
enum PageTreeExpansionMotion {
    static let animation = Animation.smooth(duration: 0.3)

    static func toggle(
        node: PageTreeNode,
        viewModel: PageTreeViewModel,
        appState: AppState,
        reduceMotion: Bool
    ) {
        let transactionAnimation = reduceMotion ? nil : animation
        let shouldLoadChildren = withAnimation(transactionAnimation) {
            viewModel.toggleExpansion(node: node)
        }

        guard shouldLoadChildren else { return }

        Task {
            guard let result = await viewModel.loadChildren(for: node, appState: appState) else {
                return
            }
            withAnimation(transactionAnimation) {
                viewModel.applyLoadedChildren(result)
            }
        }
    }
}
