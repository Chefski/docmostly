import Foundation

nonisolated struct NativeEditorRemoteTextPosition: Equatable, Sendable {
    let blockIndex: Int
    let characterOffset: Int
}

nonisolated struct NativeEditorResolvedRemoteCursor: Equatable, Identifiable, Sendable {
    let id: String
    let collaboratorID: String
    let name: String
    let colorName: String
    let anchor: NativeEditorRemoteTextPosition
    let head: NativeEditorRemoteTextPosition

    init(
        id: String,
        collaboratorID: String? = nil,
        name: String,
        colorName: String,
        anchor: NativeEditorRemoteTextPosition,
        head: NativeEditorRemoteTextPosition
    ) {
        self.id = id
        self.collaboratorID = collaboratorID ?? id
        self.name = name
        self.colorName = colorName
        self.anchor = anchor
        self.head = head
    }

    var isCollapsed: Bool {
        anchor == head
    }
}
