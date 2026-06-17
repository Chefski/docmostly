import Foundation

struct NativeEditorRemoteCursor: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let colorName: String
    let cursor: NativeEditorAwarenessCursor

    init(id: String, name: String, colorName: String, cursor: NativeEditorAwarenessCursor) {
        self.id = id
        self.name = name
        self.colorName = colorName
        self.cursor = cursor
    }

    init?(awarenessState: NativeEditorAwarenessState) {
        guard let cursor = awarenessState.cursor else { return nil }
        guard cursor.targetsDocmostDefaultFragment else { return nil }

        let collaborator = NativeEditorCollaborator(awarenessState: awarenessState)
        id = collaborator.id
        name = collaborator.name
        colorName = collaborator.colorName
        self.cursor = cursor
    }
}
