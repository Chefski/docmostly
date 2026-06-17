import SwiftUI

struct PageTreeNodeView: View {
    @Environment(AppState.self) private var appState

    let node: PageTreeNode
    let depth: Int
    let viewModel: PageTreeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                if node.hasChildren {
                    Button(expandButtonTitle, systemImage: expandButtonImage, action: toggle)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                        .accessibilityLabel(expandButtonTitle)
                } else {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(.tertiary)
                        .frame(width: 28)
                        .accessibilityHidden(true)
                }

                NavigationLink(value: node) {
                    Label {
                        Text(node.title)
                            .lineLimit(2)
                    } icon: {
                        Text(node.icon?.isEmpty == false ? node.icon ?? "" : "📄")
                    }
                }
            }
            .padding(.leading, Double(depth) * 16)
            .contentShape(.rect)
            .listRowBackground(appState.selectedPageID == node.slugId ? DocmostlyTheme.primaryTint : nil)

            if viewModel.expandedIDs.contains(node.id) {
                ForEach(node.children) { child in
                    PageTreeNodeView(node: child, depth: depth + 1, viewModel: viewModel)
                }
            }
        }
    }

    private var expandButtonImage: String {
        viewModel.expandedIDs.contains(node.id) ? "chevron.down" : "chevron.right"
    }

    private var expandButtonTitle: String {
        viewModel.expandedIDs.contains(node.id) ? "Collapse \(node.title)" : "Expand \(node.title)"
    }

    private func toggle() {
        Task {
            await viewModel.toggle(node: node, appState: appState)
        }
    }
}
