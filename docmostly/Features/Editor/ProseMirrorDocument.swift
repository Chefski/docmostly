import Foundation

struct ProseMirrorDocument: Codable, Hashable, Sendable {
    var type: String
    var content: [ProseMirrorNode]

    init(type: String = "doc", content: [ProseMirrorNode] = []) {
        self.type = type
        self.content = content
    }
}
