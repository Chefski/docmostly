import Testing
@testable import docmostly

struct PageTreeVisibleNodeTests {
    @Test func visibleNodesHideCollapsedChildren() {
        let nodes = [
            node(id: "root", children: [
                node(id: "child")
            ]),
            node(id: "sibling")
        ]

        let visibleNodes = nodes.visibleNodes(expandedIDs: [])

        #expect(visibleNodes.map(\.id) == ["root", "sibling"])
        #expect(visibleNodes.map(\.depth) == [0, 0])
    }

    @Test func visibleNodesIncludeExpandedChildrenWithDepth() {
        let nodes = [
            node(id: "root", children: [
                node(id: "child-1"),
                node(id: "child-2")
            ])
        ]

        let visibleNodes = nodes.visibleNodes(expandedIDs: ["root"])

        #expect(visibleNodes.map(\.id) == ["root", "child-1", "child-2"])
        #expect(visibleNodes.map(\.depth) == [0, 1, 1])
        #expect(visibleNodes.map(\.isExpanded) == [true, false, false])
    }

    @Test func visibleNodesOnlyIncludeNestedChildrenWhenEachAncestorIsExpanded() {
        let nodes = [
            node(id: "root", children: [
                node(id: "child", children: [
                    node(id: "grandchild")
                ])
            ])
        ]

        let parentOnly = nodes.visibleNodes(expandedIDs: ["root"])
        let nested = nodes.visibleNodes(expandedIDs: ["root", "child"])

        #expect(parentOnly.map(\.id) == ["root", "child"])
        #expect(nested.map(\.id) == ["root", "child", "grandchild"])
        #expect(nested.map(\.depth) == [0, 1, 2])
    }

    private func node(
        id: String,
        children: [PageTreeNode] = []
    ) -> PageTreeNode {
        PageTreeNode(
            id: id,
            slugId: id,
            title: id,
            icon: nil,
            spaceId: "space-1",
            parentPageId: nil,
            position: nil,
            hasChildren: children.isEmpty == false,
            children: children,
            isChildrenLoaded: children.isEmpty == false
        )
    }
}
