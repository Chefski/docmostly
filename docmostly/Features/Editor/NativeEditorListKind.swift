import Foundation

nonisolated enum NativeEditorListKind: Equatable {
    case bullet
    case ordered
    case task

    var nodeType: String {
        switch self {
        case .bullet:
            "bulletList"
        case .ordered:
            "orderedList"
        case .task:
            "taskList"
        }
    }

    func attrs(from block: NativeEditorBlock) -> [String: ProseMirrorJSONValue]? {
        guard case .orderedListItem(let ordinal) = block.kind, ordinal != 1 else {
            return nil
        }

        return ["start": .int(ordinal)]
    }
}
