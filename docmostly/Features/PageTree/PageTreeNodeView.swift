import SwiftUI

struct PageTreeNodeView: View {
    @Environment(AppState.self) private var appState

    let node: PageTreeNode
    let depth: Int
    let viewModel: PageTreeViewModel
    let createChild: (PageTreeNode) -> Void
    let duplicate: (PageTreeNode) -> Void
    let moveToSpace: (PageTreeNode) -> Void
    let delete: (PageTreeNode) -> Void

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
            .draggable(node.id)
            .dropDestination(for: String.self, action: handleDrop)
            .contextMenu {
                Button("New subpage", systemImage: "plus") {
                    createChild(node)
                }
                Button("Duplicate", systemImage: "doc.on.doc") {
                    duplicate(node)
                }
                Button("Move to Space", systemImage: "folder") {
                    moveToSpace(node)
                }
                Button("Move to Trash", systemImage: "trash", role: .destructive) {
                    delete(node)
                }
            }

            if viewModel.expandedIDs.contains(node.id) {
                ForEach(node.children) { child in
                    PageTreeNodeView(
                        node: child,
                        depth: depth + 1,
                        viewModel: viewModel,
                        createChild: createChild,
                        duplicate: duplicate,
                        moveToSpace: moveToSpace,
                        delete: delete
                    )
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

    private func handleDrop(pageIDs: [String], location: CGPoint) -> Bool {
        guard let pageID = pageIDs.first, pageID != node.id else { return false }

        Task {
            await viewModel.movePage(
                sourceID: pageID,
                operation: .makeChild(targetID: node.id),
                appState: appState
            )
        }
        return true
    }
}
