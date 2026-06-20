import Foundation

nonisolated enum PageTreeError: Error, Equatable, LocalizedError {
    case missingSource
    case missingTarget
    case invalidDescendantMove
    case missingMoveResult

    var errorDescription: String? {
        switch self {
        case .missingSource:
            "The page being moved is no longer in the tree."
        case .missingTarget:
            "The target page is no longer in the tree."
        case .invalidDescendantMove:
            "A page cannot be moved into one of its own subpages."
        case .missingMoveResult:
            "The moved page could not be placed in the tree."
        }
    }
}
