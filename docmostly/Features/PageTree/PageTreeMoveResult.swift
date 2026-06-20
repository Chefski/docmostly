import Foundation

nonisolated struct PageTreeMoveResult: Equatable, Sendable {
    let tree: [PageTreeNode]
    let parentPageId: String?
    let index: Int
}
