import Foundation

nonisolated struct ProseMirrorMark: Codable, Hashable, Sendable {
    var type: String
    var attrs: [String: ProseMirrorJSONValue]?

    init(type: String, attrs: [String: ProseMirrorJSONValue]? = nil) {
        self.type = type
        self.attrs = attrs
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case attrs
    }

    init(from decoder: Decoder) throws {
        try ProseMirrorDecodingLimits.validateCodingDepth(decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        attrs = try container.decodeIfPresent([String: ProseMirrorJSONValue].self, forKey: .attrs)
        if let attrs {
            try ProseMirrorDecodingLimits.validateAttributeCount(attrs.count, decoder: decoder)
        }
    }
}
