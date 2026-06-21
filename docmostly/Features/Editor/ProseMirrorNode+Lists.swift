import Foundation

nonisolated extension ProseMirrorNode {
    var isListContainer: Bool {
        type == "bulletList" || type == "orderedList" || type == "taskList"
    }
}
