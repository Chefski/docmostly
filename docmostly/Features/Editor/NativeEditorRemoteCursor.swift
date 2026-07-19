import Foundation

nonisolated struct NativeEditorRemoteCursor: Equatable, Identifiable, Sendable {
    let id: String
    let collaboratorID: String
    let name: String
    let colorName: String
    let cursor: NativeEditorAwarenessCursor

    init(
        id: String,
        collaboratorID: String? = nil,
        name: String,
        colorName: String,
        cursor: NativeEditorAwarenessCursor
    ) {
        self.id = id
        self.collaboratorID = collaboratorID ?? id
        self.name = name
        self.colorName = colorName
        self.cursor = cursor
    }

    init?(awarenessState: NativeEditorAwarenessState) {
        guard let cursor = awarenessState.cursor else { return nil }
        guard cursor.targetsDocmostDefaultFragment else { return nil }

        let user = awarenessState.payload?.user
        id = "client-\(awarenessState.clientID)"
        collaboratorID = user?.id ?? id
        name = user?.name ?? "Someone"
        colorName = user?.color ?? NativeEditorPresenceColor.color(for: collaboratorID)
        self.cursor = cursor
    }
}
