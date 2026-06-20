import Foundation

nonisolated struct PageTreeMovePayload: Equatable, Sendable {
    let pageId: String
    let parentPageId: String?
    let position: String
}
