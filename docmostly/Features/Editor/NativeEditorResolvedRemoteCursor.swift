import Foundation

struct NativeEditorRemoteTextPosition: Equatable, Sendable {
    let blockIndex: Int
    let characterOffset: Int
}

struct NativeEditorResolvedRemoteCursor: Equatable, Identifiable, Sendable {
    let id: String
    let name: String
    let colorName: String
    let anchor: NativeEditorRemoteTextPosition
    let head: NativeEditorRemoteTextPosition

    var isCollapsed: Bool {
        anchor == head
    }
}
