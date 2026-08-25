import Foundation

nonisolated struct PageTreeChildLoadResult: Sendable {
    let parentID: String
    let treeRevision: Int
    let childNodes: [PageTreeNode]
}
