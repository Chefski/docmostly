import Foundation

nonisolated struct PageTreeSiblingsInfo: Equatable, Sendable {
    let parentPageId: String?
    let siblings: [PageTreeNode]
    let index: Int
}
