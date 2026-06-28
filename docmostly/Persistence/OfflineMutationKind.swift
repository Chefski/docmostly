import Foundation

nonisolated enum OfflineMutationKind: String, Codable, CaseIterable, Sendable {
    case updatePage
    case createComment
    case resolveComment
    case addPageLabels
    case removePageLabel
    case addFavorite
    case removeFavorite
    case watchPage
    case unwatchPage
    case watchSpace
    case unwatchSpace
    case movePage
    case movePageToSpace
}
