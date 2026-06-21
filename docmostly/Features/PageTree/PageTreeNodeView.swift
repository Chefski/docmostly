import SwiftUI

struct PageTreeNodeView: View {
    let node: PageTreeNode
    let depth: Int
    let isExpanded: Bool
    let isSelected: Bool
    let toggle: (PageTreeNode) -> Void
    let openInDetailColumn: (PageTreeNode) -> Void
    let movePage: (String, PageTreeDropOperation) -> Void
    let createChild: (PageTreeNode) -> Void
    let duplicate: (PageTreeNode) -> Void
    let moveToSpace: (PageTreeNode) -> Void
    let delete: (PageTreeNode) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: PageTreeSidebarMetrics.branchSpacing) {
            HStack(spacing: PageTreeSidebarMetrics.columnSpacing) {
                PageTreeDisclosureColumn(
                    hasChildren: node.hasChildren,
                    isExpanded: isExpanded,
                    title: node.title,
                    toggle: toggleNode
                )

                #if os(macOS)
                Button(action: openNodeInDetailColumn) {
                    PageTreeNodeLabel(node: node)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(node.title)
                #else
                NavigationLink(value: node) {
                    PageTreeNodeLabel(node: node)
                }
                #endif
            }
            .padding(.leading, CGFloat(depth) * PageTreeSidebarMetrics.depthIndent)
            .frame(maxWidth: .infinity, minHeight: PageTreeSidebarMetrics.rowHeight, alignment: .leading)
            .contentShape(.rect)
            .background(
                isSelected ? DocmostlyTheme.primaryTint : Color.clear,
                in: .rect(cornerRadius: PageTreeSidebarMetrics.selectionCornerRadius)
            )
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
        }
        .listRowInsets(PageTreeSidebarMetrics.listRowInsets)
        .listRowSeparator(.hidden)
    }

    private func toggleNode() {
        toggle(node)
    }

    private func openNodeInDetailColumn() {
        openInDetailColumn(node)
    }

    private func handleDrop(pageIDs: [String], location: CGPoint) -> Bool {
        guard let pageID = pageIDs.first, pageID != node.id else { return false }

        movePage(pageID, .makeChild(targetID: node.id))
        return true
    }
}

enum PageTreeSidebarMetrics {
    static let rowHeight: CGFloat = 26
    static let branchSpacing: CGFloat = 0
    static let depthIndent: CGFloat = 18
    static let columnSpacing: CGFloat = 5
    static let iconTitleSpacing: CGFloat = 8
    static let disclosureWidth: CGFloat = 22
    static let iconWidth: CGFloat = 26
    static let selectionCornerRadius: CGFloat = 6
    static let leafBulletSize: CGFloat = 5
    static let listRowInsets = EdgeInsets(top: 1, leading: 0, bottom: 1, trailing: 0)
}

private struct PageTreeDisclosureColumn: View {
    let hasChildren: Bool
    let isExpanded: Bool
    let title: String
    let toggle: () -> Void

    var body: some View {
        if hasChildren {
            Button(expandButtonTitle, systemImage: expandButtonImage, action: toggle)
                .labelStyle(.iconOnly)
                .buttonStyle(.plain)
                .imageScale(.medium)
                .foregroundStyle(.secondary)
                .frame(width: PageTreeSidebarMetrics.disclosureWidth, height: PageTreeSidebarMetrics.rowHeight)
                .accessibilityLabel(expandButtonTitle)
        } else {
            Image(systemName: "circle.fill")
                .resizable()
                .frame(width: PageTreeSidebarMetrics.leafBulletSize, height: PageTreeSidebarMetrics.leafBulletSize)
                .foregroundStyle(.tertiary)
                .frame(width: PageTreeSidebarMetrics.disclosureWidth, height: PageTreeSidebarMetrics.rowHeight)
                .accessibilityHidden(true)
        }
    }

    private var expandButtonImage: String {
        isExpanded ? "chevron.down" : "chevron.right"
    }

    private var expandButtonTitle: String {
        isExpanded ? "Collapse \(title)" : "Expand \(title)"
    }
}

private struct PageTreeNodeLabel: View {
    let node: PageTreeNode

    var body: some View {
        HStack(spacing: PageTreeSidebarMetrics.iconTitleSpacing) {
            PageTreeNodeIcon(icon: node.icon)

            Text(node.title)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: PageTreeSidebarMetrics.rowHeight, alignment: .leading)
        .contentShape(.rect)
    }
}

private struct PageTreeNodeIcon: View {
    let icon: String?

    var body: some View {
        Group {
            if let icon, icon.isEmpty == false {
                Text(icon)
                    .font(.body)
                    .lineLimit(1)
            } else {
                Image(systemName: "doc.text")
                    .font(.body)
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: PageTreeSidebarMetrics.iconWidth, height: PageTreeSidebarMetrics.rowHeight)
        .accessibilityHidden(true)
    }
}
