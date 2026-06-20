import Testing
@testable import docmostly

struct PageTreeMovePayloadTests {
    @Test func reorderBeforeComputesParentAndPositionFromPostMoveNeighbors() throws {
        let payload = try tree.movePayload(
            sourceID: "a2",
            operation: .reorderBefore(targetID: "a1")
        )

        #expect(payload == PageTreeMovePayload(pageId: "a2", parentPageId: "a", position: "Zz"))
    }

    @Test func reorderAfterComputesParentAndPositionFromPostMoveNeighbors() throws {
        let payload = try tree.movePayload(
            sourceID: "a1",
            operation: .reorderAfter(targetID: "a2")
        )

        #expect(payload == PageTreeMovePayload(pageId: "a1", parentPageId: "a", position: "a2"))
    }

    @Test func makeChildAppendsUnderTarget() throws {
        let payload = try tree.movePayload(
            sourceID: "b",
            operation: .makeChild(targetID: "a")
        )

        #expect(payload == PageTreeMovePayload(pageId: "b", parentPageId: "a", position: "a2"))
    }

    @Test func adjacentMovesUsePostMoveNeighbors() throws {
        let adjacent = [
            node(id: "a", position: "a0"),
            node(id: "b", position: "a0V"),
            node(id: "c", position: "a1"),
            node(id: "d", position: "a1V")
        ]

        let afterTarget = try adjacent.movePayload(
            sourceID: "b",
            operation: .reorderAfter(targetID: "a")
        )
        let beforeTarget = try adjacent.movePayload(
            sourceID: "b",
            operation: .reorderBefore(targetID: "c")
        )

        #expect(afterTarget == PageTreeMovePayload(pageId: "b", parentPageId: nil, position: "a0V"))
        #expect(beforeTarget == PageTreeMovePayload(pageId: "b", parentPageId: nil, position: "a0V"))
    }

    private var tree: [PageTreeNode] {
        [
            node(id: "a", position: "a0", children: [
                node(id: "a1", parentPageId: "a", position: "a0"),
                node(id: "a2", parentPageId: "a", position: "a1")
            ]),
            node(id: "b", position: "a1")
        ]
    }

    private func node(
        id: String,
        parentPageId: String? = nil,
        position: String,
        children: [PageTreeNode] = []
    ) -> PageTreeNode {
        PageTreeNode(
            id: id,
            slugId: "\(id)-slug",
            title: id,
            icon: nil,
            spaceId: "space-1",
            parentPageId: parentPageId,
            position: position,
            hasChildren: children.isEmpty == false,
            children: children,
            isChildrenLoaded: children.isEmpty == false
        )
    }
}
