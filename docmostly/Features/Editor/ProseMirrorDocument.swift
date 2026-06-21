import Foundation

nonisolated struct ProseMirrorDocument: Codable, Hashable, Sendable {
    var type: String
    var content: [ProseMirrorNode]

    init(type: String = "doc", content: [ProseMirrorNode] = []) {
        self.type = type
        self.content = content
    }

    private enum CodingKeys: String, CodingKey {
        case type
        case content
    }

    init(from decoder: Decoder) throws {
        try ProseMirrorDecodingLimits.validateCodingDepth(decoder)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "doc"
        content = try container.decodeIfPresent([ProseMirrorNode].self, forKey: .content) ?? []
        try ProseMirrorDecodingLimits.validateChildCount(content.count, decoder: decoder)
    }

    func validateNativeEditorBudget() throws {
        var stack = content
        var nodeCount = 0

        while let node = stack.popLast() {
            nodeCount += 1
            guard nodeCount <= ProseMirrorDecodingLimits.maximumTotalNodeCount else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(
                        codingPath: [],
                        debugDescription: "ProseMirror document has too many nodes."
                    )
                )
            }

            if let childContent = node.content {
                stack.append(contentsOf: childContent)
            }
        }
    }

    var isWithinNativeEditorBudget: Bool {
        (try? validateNativeEditorBudget()) != nil
    }
}
