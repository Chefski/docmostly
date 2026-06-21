import Foundation

nonisolated enum ProseMirrorDecodingLimits {
    static let maximumCodingPathDepth = 256
    static let maximumChildNodesPerNode = 1_000
    static let maximumMarksPerNode = 128
    static let maximumAttributesPerNode = 256
    static let maximumTextLength = 1_000_000
    static let maximumTotalNodeCount = 100_000

    static func validateCodingDepth(_ decoder: Decoder) throws {
        guard decoder.codingPath.count <= maximumCodingPathDepth else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "ProseMirror document exceeds the supported nesting depth."
                )
            )
        }
    }

    static func validateChildCount(_ count: Int, decoder: Decoder) throws {
        guard count <= maximumChildNodesPerNode else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "ProseMirror node has too many child nodes."
                )
            )
        }
    }

    static func validateMarkCount(_ count: Int, decoder: Decoder) throws {
        guard count <= maximumMarksPerNode else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "ProseMirror node has too many marks."
                )
            )
        }
    }

    static func validateAttributeCount(_ count: Int, decoder: Decoder) throws {
        guard count <= maximumAttributesPerNode else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "ProseMirror node has too many attributes."
                )
            )
        }
    }

    static func validateTextLength(_ count: Int, decoder: Decoder) throws {
        guard count <= maximumTextLength else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "ProseMirror text node is too large."
                )
            )
        }
    }
}

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

    private enum CodingKeys: String, CodingKey {
        case type
        case attrs
        case content
        case marks
        case text
    }

    init(from decoder: Decoder) throws {
        try ProseMirrorDecodingLimits.validateCodingDepth(decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        attrs = try container.decodeIfPresent([String: ProseMirrorJSONValue].self, forKey: .attrs)
        if let attrs {
            try ProseMirrorDecodingLimits.validateAttributeCount(attrs.count, decoder: decoder)
        }
        content = try container.decodeIfPresent([ProseMirrorNode].self, forKey: .content)
        if let content {
            try ProseMirrorDecodingLimits.validateChildCount(content.count, decoder: decoder)
        }
        marks = try container.decodeIfPresent([ProseMirrorMark].self, forKey: .marks)
        if let marks {
            try ProseMirrorDecodingLimits.validateMarkCount(marks.count, decoder: decoder)
        }
        text = try container.decodeIfPresent(String.self, forKey: .text)
        if let text {
            try ProseMirrorDecodingLimits.validateTextLength(text.count, decoder: decoder)
        }
    }
}
