import Foundation

nonisolated extension ProseMirrorDocument {
    func isCollaborationEquivalent(to other: ProseMirrorDocument) -> Bool {
        self == other
    }
}
