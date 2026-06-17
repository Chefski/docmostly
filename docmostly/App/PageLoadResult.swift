import Foundation

nonisolated struct PageLoadResult: Sendable {
    let page: DocmostPage
    let html: String
    let isFromCache: Bool
}
