import Foundation

nonisolated struct ProseMirrorNode: Codable, Hashable, Sendable {
    var type: String
    var attrs: [String: ProseMirrorJSONValue]?
    var content: [ProseMirrorNode]?
    var marks: [ProseMirrorMark]?
    var text: String?

    init(
        type: String,
        attrs: [String: ProseMirrorJSONValue]? = nil,
        content: [ProseMirrorNode]? = nil,
        marks: [ProseMirrorMark]? = nil,
        text: String? = nil
    ) {
        self.type = type
        self.attrs = attrs
        self.content = content
        self.marks = marks
        self.text = text
    }
}
