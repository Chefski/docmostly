import Foundation

nonisolated struct PageTreeVisibleNode: Identifiable, Hashable, Sendable {
    let node: PageTreeNode
    let depth: Int
    let isExpanded: Bool

    var id: String {
        node.id
    }
}

nonisolated extension Array where Element == PageTreeNode {
    func visibleNodes(expandedIDs: Set<String>, depth: Int = 0) -> [PageTreeVisibleNode] {
        var visibleNodes: [PageTreeVisibleNode] = []
        visibleNodes.reserveCapacity(count)
        appendVisibleNodes(to: &visibleNodes, expandedIDs: expandedIDs, depth: depth)
        return visibleNodes
    }

    private func appendVisibleNodes(
        to visibleNodes: inout [PageTreeVisibleNode],
        expandedIDs: Set<String>,
        depth: Int
    ) {
        for node in self {
            let isExpanded = expandedIDs.contains(node.id)
            visibleNodes.append(PageTreeVisibleNode(node: node, depth: depth, isExpanded: isExpanded))

            if isExpanded {
                node.children.appendVisibleNodes(
                    to: &visibleNodes,
                    expandedIDs: expandedIDs,
                    depth: depth + 1
                )
            }
        }
    }
}
