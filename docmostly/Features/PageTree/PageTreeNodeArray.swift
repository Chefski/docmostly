import Foundation

extension Array where Element == PageTreeNode {
    func sortedByPosition() -> [PageTreeNode] {
        sorted { lhs, rhs in
            (lhs.position ?? "") < (rhs.position ?? "")
        }
    }

    mutating func updateNode(id: String, update: (inout PageTreeNode) -> Void) {
        for index in indices {
            if self[index].id == id {
                update(&self[index])
                return
            }

            self[index].children.updateNode(id: id, update: update)
        }
    }
}
