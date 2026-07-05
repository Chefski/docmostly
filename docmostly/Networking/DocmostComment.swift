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
    let spaceId: String?
    let createdAt: Date?
    let editedAt: Date?
    let deletedAt: Date?
    let creator: DocmostUser?
    let resolvedBy: DocmostUser?
    let isNativelyEditable: Bool

    var isResolved: Bool {
        resolvedAt != nil
    }

    var isLocallyQueued: Bool {
        id.hasPrefix("offline-comment-")
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
        case spaceId
        case createdAt
        case editedAt
        case deletedAt
        case creator
        case resolvedBy
    }

    init(
        id: String,
        content: String?,
        selection: String?,
        type: String?,
        creatorId: String,
        pageId: String,
        parentCommentId: String? = nil,
        resolvedById: String? = nil,
        resolvedAt: Date? = nil,
        workspaceId: String? = nil,
        spaceId: String? = nil,
        createdAt: Date? = nil,
        editedAt: Date? = nil,
        deletedAt: Date? = nil,
        creator: DocmostUser? = nil,
        resolvedBy: DocmostUser? = nil,
        isNativelyEditable: Bool = true
    ) {
        self.id = id
        self.content = content
        self.selection = selection
        self.type = type
        self.creatorId = creatorId
        self.pageId = pageId
        self.parentCommentId = parentCommentId
        self.resolvedById = resolvedById
        self.resolvedAt = resolvedAt
        self.workspaceId = workspaceId
        self.spaceId = spaceId
        self.createdAt = createdAt
        self.editedAt = editedAt
        self.deletedAt = deletedAt
        self.creator = creator
        self.resolvedBy = resolvedBy
        self.isNativelyEditable = isNativelyEditable
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decode(String.self, forKey: .id)
        let decodedContent = Self.decodeContent(from: container)
        content = decodedContent.text
        isNativelyEditable = decodedContent.isNativelyEditable
        selection = try container.decodeIfPresent(String.self, forKey: .selection)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        creatorId = try container.decode(String.self, forKey: .creatorId)
        pageId = try container.decode(String.self, forKey: .pageId)
        parentCommentId = try container.decodeIfPresent(String.self, forKey: .parentCommentId)
        resolvedById = try container.decodeIfPresent(String.self, forKey: .resolvedById)
        resolvedAt = try container.decodeIfPresent(Date.self, forKey: .resolvedAt)
        workspaceId = try container.decodeIfPresent(String.self, forKey: .workspaceId)
        spaceId = try container.decodeIfPresent(String.self, forKey: .spaceId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        editedAt = try container.decodeIfPresent(Date.self, forKey: .editedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        creator = try container.decodeIfPresent(DocmostUser.self, forKey: .creator)
        resolvedBy = try container.decodeIfPresent(DocmostUser.self, forKey: .resolvedBy)
    }

    private static func decodeContent(
        from container: KeyedDecodingContainer<CodingKeys>
    ) -> CommentContentDecodingResult {
        if let content = try? container.decodeIfPresent(String.self, forKey: .content) {
            return CommentContentDecodingResult(text: content, isNativelyEditable: true)
        }

        guard let document = try? container.decodeIfPresent(CommentContentNode.self, forKey: .content) else {
            return CommentContentDecodingResult(text: nil, isNativelyEditable: false)
        }

        guard let text = try? document.plainText() else {
            return CommentContentDecodingResult(text: nil, isNativelyEditable: false)
        }
        return CommentContentDecodingResult(
            text: text.isEmpty ? nil : text,
            isNativelyEditable: document.isPlainTextDocument
        )
    }
}

nonisolated private struct CommentContentDecodingResult {
    let text: String?
    let isNativelyEditable: Bool
}

nonisolated enum CommentContentDecodingLimits {
    static let maximumDepth = 64
    static let maximumChildrenPerNode = 256
    static let maximumNodeCount = 10_000
    static let maximumTextLength = 100_000
    static let maximumAggregateTextLength = 500_000
}

nonisolated private struct CommentContentNode: Decodable {
    let type: String?
    let text: String?
    let content: [CommentContentNode]?
    let hasAttrs: Bool
    let hasMarks: Bool

    private enum CodingKeys: String, CodingKey {
        case type
        case text
        case content
        case attrs
        case marks
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
        type = try container.decodeIfPresent(String.self, forKey: .type)
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
        hasAttrs = container.contains(.attrs)
        hasMarks = container.contains(.marks)
    }

    var isPlainTextDocument: Bool {
        guard type == "doc",
              hasAttrs == false,
              hasMarks == false,
              let content,
              content.isEmpty == false else {
            return false
        }
        return content.allSatisfy(\.isPlainTextParagraph)
    }

    private var isPlainTextParagraph: Bool {
        guard type == "paragraph",
              text == nil,
              hasAttrs == false,
              hasMarks == false else {
            return false
        }
        return content?.allSatisfy(\.isPlainTextTextNode) ?? true
    }

    private var isPlainTextTextNode: Bool {
        type == "text"
            && text != nil
            && content == nil
            && hasAttrs == false
            && hasMarks == false
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

        if type == "doc" {
            var paragraphTexts: [String] = []
            for child in content ?? [] {
                paragraphTexts.append(
                    try child.plainText(remainingNodes: &remainingNodes, remainingText: &remainingText)
                )
            }
            return paragraphTexts.joined(separator: "\n")
        }

        if let text, text.isEmpty == false {
            remainingText -= text.count
            guard remainingText >= 0 else {
                throw DecodingError.dataCorrupted(
                    DecodingError.Context(codingPath: [], debugDescription: "Comment content is too large.")
                )
            }
            return text
        }

        var parts: [String] = []
        for child in content ?? [] {
            let childText = try child.plainText(remainingNodes: &remainingNodes, remainingText: &remainingText)
            if childText.isEmpty == false {
                parts.append(childText)
            }
        }

        return parts.joined(separator: type == "paragraph" ? "" : " ")
    }
}
