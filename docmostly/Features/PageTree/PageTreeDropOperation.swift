import Foundation

nonisolated enum PageTreeDropOperation: Equatable, Sendable {
    case reorderBefore(targetID: String)
    case reorderAfter(targetID: String)
    case makeChild(targetID: String)

    var targetID: String {
        switch self {
        case .reorderBefore(let targetID), .reorderAfter(let targetID), .makeChild(let targetID):
            targetID
        }
    }
}
