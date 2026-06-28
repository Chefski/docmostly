import Foundation

nonisolated enum ProseMirrorDecodingLimits {
    static let maximumCodingPathDepth = 256
    static let maximumChildNodesPerNode = 1_000
    static let maximumMarksPerNode = 128
    static let maximumAttributesPerNode = 256
    static let maximumTextLength = 1_000_000
    static let maximumAttributeStringLength = 100_000
    static let maximumAttributeAggregateCharacters = 1_000_000
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

    static func dataCorrupted(codingPath: [any CodingKey], description: String) -> DecodingError {
        DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: codingPath, debugDescription: description)
        )
    }
}

nonisolated extension CodingUserInfoKey {
    static let proseMirrorDecodingBudget = CodingUserInfoKey(rawValue: "proseMirrorDecodingBudget")!
}

nonisolated final class ProseMirrorDecodingBudget: @unchecked Sendable {
    private var nodeCount = 0

    func consumeNode(decoder: Decoder) throws {
        nodeCount += 1
        guard nodeCount <= ProseMirrorDecodingLimits.maximumTotalNodeCount else {
            throw ProseMirrorDecodingLimits.dataCorrupted(
                codingPath: decoder.codingPath,
                description: "ProseMirror document has too many nodes."
            )
        }
    }

    func validateAttributes(
        _ attrs: [String: ProseMirrorJSONValue],
        decoder: Decoder
    ) throws {
        var aggregateCharacters = 0
        for (key, value) in attrs {
            aggregateCharacters += key.count
            try validateAggregateCharacters(aggregateCharacters, decoder: decoder)
            try validateAttributeValue(value, aggregateCharacters: &aggregateCharacters, decoder: decoder)
        }
    }

    private func validateAttributeValue(
        _ value: ProseMirrorJSONValue,
        aggregateCharacters: inout Int,
        decoder: Decoder
    ) throws {
        guard aggregateCharacters <= ProseMirrorDecodingLimits.maximumAttributeAggregateCharacters else {
            throw ProseMirrorDecodingLimits.dataCorrupted(
                codingPath: decoder.codingPath,
                description: "ProseMirror attributes are too large."
            )
        }

        switch value {
        case .string(let string):
            guard string.count <= ProseMirrorDecodingLimits.maximumAttributeStringLength else {
                throw ProseMirrorDecodingLimits.dataCorrupted(
                    codingPath: decoder.codingPath,
                    description: "ProseMirror attribute string is too large."
                )
            }
            aggregateCharacters += string.count
            try validateAggregateCharacters(aggregateCharacters, decoder: decoder)
        case .object(let object):
            aggregateCharacters += object.keys.reduce(0) { $0 + $1.count }
            try validateAggregateCharacters(aggregateCharacters, decoder: decoder)
            for nestedValue in object.values {
                try validateAttributeValue(
                    nestedValue,
                    aggregateCharacters: &aggregateCharacters,
                    decoder: decoder
                )
            }
        case .array(let array):
            for nestedValue in array {
                try validateAttributeValue(
                    nestedValue,
                    aggregateCharacters: &aggregateCharacters,
                    decoder: decoder
                )
            }
        case .int, .double, .bool, .null:
            break
        }
    }

    private func validateAggregateCharacters(_ aggregateCharacters: Int, decoder: Decoder) throws {
        guard aggregateCharacters <= ProseMirrorDecodingLimits.maximumAttributeAggregateCharacters else {
            throw ProseMirrorDecodingLimits.dataCorrupted(
                codingPath: decoder.codingPath,
                description: "ProseMirror attributes are too large."
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
        try (decoder.userInfo[.proseMirrorDecodingBudget] as? ProseMirrorDecodingBudget)?
            .consumeNode(decoder: decoder)
        try ProseMirrorDecodingLimits.validateCodingDepth(decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        attrs = try container.decodeIfPresent([String: ProseMirrorJSONValue].self, forKey: .attrs)
        if let attrs {
            try ProseMirrorDecodingLimits.validateAttributeCount(attrs.count, decoder: decoder)
            try (decoder.userInfo[.proseMirrorDecodingBudget] as? ProseMirrorDecodingBudget)?
                .validateAttributes(attrs, decoder: decoder)
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
