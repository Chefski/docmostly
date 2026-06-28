import Foundation

nonisolated struct DocmostComment: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let content: String?
    let selection: String?
    let type: String?
    let creatorId: String
    let pageId: String
    let parentCommentId: String?
    let resolvedById: String?
    let resolvedAt: Date?
    let workspaceId: String?
    let createdAt: Date?
    let editedAt: Date?
    let deletedAt: Date?
    let creator: DocmostUser?
    let resolvedBy: DocmostUser?

    var isResolved: Bool {
        resolvedAt != nil
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case content
        case selection
        case type
        case creatorId
        case pageId
        case parentCommentId
        case resolvedById
        case resolvedAt
        case workspaceId
        case createdAt
        case editedAt
        case deletedAt
        case creator
        case resolvedBy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        content = Self.decodeContent(from: container)
        selection = try container.decodeIfPresent(String.self, forKey: .selection)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        creatorId = try container.decode(String.self, forKey: .creatorId)
        pageId = try container.decode(String.self, forKey: .pageId)
        parentCommentId = try container.decodeIfPresent(String.self, forKey: .parentCommentId)
        resolvedById = try container.decodeIfPresent(String.self, forKey: .resolvedById)
        resolvedAt = try container.decodeIfPresent(Date.self, forKey: .resolvedAt)
        workspaceId = try container.decodeIfPresent(String.self, forKey: .workspaceId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        editedAt = try container.decodeIfPresent(Date.self, forKey: .editedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        creator = try container.decodeIfPresent(DocmostUser.self, forKey: .creator)
        resolvedBy = try container.decodeIfPresent(DocmostUser.self, forKey: .resolvedBy)
    }

    private static func decodeContent(from container: KeyedDecodingContainer<CodingKeys>) -> String? {
        if let content = try? container.decodeIfPresent(String.self, forKey: .content) {
            return content
        }

        guard let document = try? container.decodeIfPresent(CommentContentNode.self, forKey: .content) else {
            return nil
        }

        guard let text = try? document.plainText() else {
            return nil
        }
        return text.isEmpty ? nil : text
    }
}

nonisolated enum CommentContentDecodingLimits {
    static let maximumDepth = 64
    static let maximumChildrenPerNode = 256
    static let maximumNodeCount = 10_000
    static let maximumTextLength = 100_000
    static let maximumAggregateTextLength = 500_000
}

nonisolated private struct CommentContentNode: Decodable {
    let text: String?
    let content: [CommentContentNode]?

    private enum CodingKeys: String, CodingKey {
        case text
        case content
    }

    init(from decoder: Decoder) throws {
        guard decoder.codingPath.count <= CommentContentDecodingLimits.maximumDepth else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Comment content exceeds the supported nesting depth."
                )
            )
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        text = try container.decodeIfPresent(String.self, forKey: .text)
        if let text, text.count > CommentContentDecodingLimits.maximumTextLength {
            throw DecodingError.dataCorruptedError(
                forKey: .text,
                in: container,
                debugDescription: "Comment text is too large."
            )
        }
        content = try container.decodeIfPresent([CommentContentNode].self, forKey: .content)
        if let content, content.count > CommentContentDecodingLimits.maximumChildrenPerNode {
            throw DecodingError.dataCorruptedError(
                forKey: .content,
                in: container,
                debugDescription: "Comment content has too many child nodes."
            )
        }
    }

    func plainText() throws -> String {
        var remainingNodes = CommentContentDecodingLimits.maximumNodeCount
        var remainingText = CommentContentDecodingLimits.maximumAggregateTextLength
        return try plainText(remainingNodes: &remainingNodes, remainingText: &remainingText)
    }

    private func plainText(remainingNodes: inout Int, remainingText: inout Int) throws -> String {
        remainingNodes -= 1
        guard remainingNodes >= 0 else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Comment content has too many nodes.")
            )
        }

        var parts: [String] = []
        if let text, text.isEmpty == false {
            remainingText -= text.count
            guard remainingText >= 0 else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: [], debugDescription: "Comment content is too large.")
                )
            }
            parts.append(text)
        }

        for child in content ?? [] {
            let childText = try child.plainText(remainingNodes: &remainingNodes, remainingText: &remainingText)
            if childText.isEmpty == false {
                parts.append(childText)
            }
        }

        return parts.joined(separator: " ")
    }
}
