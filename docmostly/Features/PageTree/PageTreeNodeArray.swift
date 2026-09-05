import Foundation

nonisolated extension Array where Element == PageTreeNode {
    func sortedByPosition() -> [PageTreeNode] {
        sorted { lhs, rhs in
            (lhs.position ?? "") < (rhs.position ?? "")
        }
    }

    func hydratingCachedDescendants(from cachedPages: [DocmostPage]) -> [PageTreeNode] {
        var childPagesByParentID: [String: [DocmostPage]] = [:]
        for page in cachedPages {
            guard let parentPageId = page.parentPageId else { continue }
            childPagesByParentID[parentPageId, default: []].append(page)
        }

        func hydrate(_ node: PageTreeNode, ancestorIDs: Set<String>) -> PageTreeNode {
            guard node.hasChildren,
                  ancestorIDs.contains(node.id) == false,
                  let childPages = childPagesByParentID[node.id],
                  childPages.isEmpty == false else {
                return node
            }

            let nextAncestorIDs = ancestorIDs.union([node.id])
            var hydratedNode = node
            hydratedNode.children = childPages
                .map(PageTreeNode.init(page:))
                .sortedByPosition()
                .filter { nextAncestorIDs.contains($0.id) == false }
                .map { hydrate($0, ancestorIDs: nextAncestorIDs) }
            hydratedNode.hasChildren = hydratedNode.children.isEmpty == false
            return hydratedNode
        }

        return map { hydrate($0, ancestorIDs: []) }
    }

    func preservingDescendants(from existingNodes: [PageTreeNode]) -> [PageTreeNode] {
        var existingNodesByID: [String: PageTreeNode] = [:]
        for node in existingNodes where existingNodesByID[node.id] == nil {
            existingNodesByID[node.id] = node
        }

        return map { node in
            guard node.hasChildren, let existingNode = existingNodesByID[node.id] else {
                return node
            }

            var mergedNode = node
            mergedNode.children = existingNode.children
            mergedNode.isChildrenLoaded = false
            return mergedNode
        }
    }

    @discardableResult
    mutating func updateNode(id: String, update: (inout PageTreeNode) -> Void) -> Bool {
        for index in indices {
            if self[index].id == id {
                update(&self[index])
                return true
            }

            if self[index].children.updateNode(id: id, update: update) {
                return true
            }
        }
        return false
    }

    func node(id: String) -> PageTreeNode? {
        for node in self {
            if node.id == id {
                return node
            }
            if let child = node.children.node(id: id) {
                return child
            }
        }
        return nil
    }

    func siblingsInfo(for id: String) -> PageTreeSiblingsInfo? {
        siblingsInfo(for: id, parentPageId: nil, siblings: self)
    }

    func containsDescendant(ancestorID: String, descendantID: String) -> Bool {
        guard ancestorID != descendantID, let ancestor = node(id: ancestorID) else { return false }
        return ancestor.children.node(id: descendantID) != nil
    }

    func movePayload(sourceID: String, operation: PageTreeDropOperation) throws -> PageTreeMovePayload {
        let moveResult = try moving(sourceID: sourceID, operation: operation)
        let info: PageTreeSiblingsInfo
        if let insertedInfo = moveResult.tree.siblingsInfo(for: sourceID) {
            info = insertedInfo
        } else if case .makeChild(let targetID) = operation,
                  let target = node(id: targetID),
                  target.isChildrenLoaded == false {
            let position = try PagePositionKeyGenerator.key(
                between: target.children.last?.position,
                and: nil
            )
            return PageTreeMovePayload(pageId: sourceID, parentPageId: targetID, position: position)
        } else {
            throw PageTreeError.missingMoveResult
        }

        let previous = info.index > 0 ? info.siblings[info.index - 1] : nil
        let nextIndex = info.index + 1
        let next = nextIndex < info.siblings.count ? info.siblings[nextIndex] : nil
        let position = try PagePositionKeyGenerator.key(
            between: previous?.position,
            and: next?.position
        )

        return PageTreeMovePayload(
            pageId: sourceID,
            parentPageId: info.parentPageId,
            position: position
        )
    }

    func moving(sourceID: String, operation: PageTreeDropOperation) throws -> PageTreeMoveResult {
        guard node(id: sourceID) != nil else { throw PageTreeError.missingSource }
        guard node(id: operation.targetID) != nil else { throw PageTreeError.missingTarget }
        guard containsDescendant(ancestorID: sourceID, descendantID: operation.targetID) == false else {
            throw PageTreeError.invalidDescendantMove
        }

        let destination = try destination(for: sourceID, operation: operation)
        let nextTree = removing(id: sourceID).inserting(
            try requireNode(id: sourceID),
            parentPageId: destination.parentPageId,
            index: destination.index
        )
        return PageTreeMoveResult(tree: nextTree, parentPageId: destination.parentPageId, index: destination.index)
    }

    func removing(id: String) -> [PageTreeNode] {
        var didRemove = false

        func walk(_ nodes: [PageTreeNode]) -> [PageTreeNode] {
            nodes.compactMap { node in
                if node.id == id {
                    didRemove = true
                    return nil
                }

                var nextNode = node
                nextNode.children = walk(node.children)
                if nextNode.isChildrenLoaded {
                    nextNode.hasChildren = nextNode.children.isEmpty == false
                }
                return nextNode
            }
        }

        let nextTree = walk(self)
        return didRemove ? nextTree : self
    }

    func inserting(_ node: PageTreeNode, parentPageId: String?, index: Int) -> [PageTreeNode] {
        var insertedNode = node
        insertedNode.parentPageId = parentPageId

        if parentPageId == nil {
            var copy = self
            copy.insert(insertedNode, at: Swift.min(Swift.max(index, 0), copy.count))
            return copy
        }

        return map { existing in
            var nextNode = existing
            if existing.id == parentPageId {
                guard nextNode.isChildrenLoaded else {
                    nextNode.hasChildren = true
                    return nextNode
                }
                let insertionIndex = Swift.min(Swift.max(index, 0), nextNode.children.count)
                nextNode.children.insert(insertedNode, at: insertionIndex)
                nextNode.hasChildren = true
                nextNode.isChildrenLoaded = true
            } else {
                nextNode.children = nextNode.children.inserting(
                    insertedNode,
                    parentPageId: parentPageId,
                    index: index
                )
            }
            return nextNode
        }
    }

    private func siblingsInfo(
        for id: String,
        parentPageId: String?,
        siblings: [PageTreeNode]
    ) -> PageTreeSiblingsInfo? {
        if let index = siblings.firstIndex(where: { $0.id == id }) {
            return PageTreeSiblingsInfo(parentPageId: parentPageId, siblings: siblings, index: index)
        }

        for node in siblings {
            if let info = siblingsInfo(for: id, parentPageId: node.id, siblings: node.children) {
                return info
            }
        }
        return nil
    }

    private func destination(
        for sourceID: String,
        operation: PageTreeDropOperation
    ) throws -> (parentPageId: String?, index: Int) {
        switch operation {
        case .makeChild(let targetID):
            let target = try requireNode(id: targetID)
            return (targetID, target.children.count)
        case .reorderBefore(let targetID), .reorderAfter(let targetID):
            guard let targetInfo = siblingsInfo(for: targetID) else {
                throw PageTreeError.missingTarget
            }
            guard let sourceInfo = siblingsInfo(for: sourceID) else {
                throw PageTreeError.missingSource
            }
            let sameParent = sourceInfo.parentPageId == targetInfo.parentPageId
            let adjust = sameParent && sourceInfo.index < targetInfo.index ? -1 : 0
            let afterOffset = operation == .reorderAfter(targetID: targetID) ? 1 : 0
            return (targetInfo.parentPageId, targetInfo.index + adjust + afterOffset)
        }
    }

    private func requireNode(id: String) throws -> PageTreeNode {
        guard let node = node(id: id) else {
            throw PageTreeError.missingSource
        }
        return node
    }
}
