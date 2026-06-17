import Foundation

nonisolated struct ProseMirrorMark: Codable, Hashable, Sendable {
    var type: String
    var attrs: [String: ProseMirrorJSONValue]?

    init(type: String, attrs: [String: ProseMirrorJSONValue]? = nil) {
        self.type = type
        self.attrs = attrs
    }
}
