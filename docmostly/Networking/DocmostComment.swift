import Foundation

nonisolated struct DocmostComment: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let content: String?
    let body: CommentBody?
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
        body: CommentBody? = nil,
        isNativelyEditable: Bool = true
    ) {
        self.id = id
        self.content = content
        self.body = body ?? content.map(CommentBody.init(plainText:))
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
        body = decodedContent.body
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
            let body = CommentBody(plainText: content)
            return CommentContentDecodingResult(text: content, body: body, isNativelyEditable: true)
        }

        guard let document = try? container.decodeIfPresent(ProseMirrorDocument.self, forKey: .content),
              Self.isWithinCommentContentBudget(document) else {
            return CommentContentDecodingResult(text: nil, body: nil, isNativelyEditable: false)
        }

        let body = CommentBody(document: document)
        let text = body.plainText
        return CommentContentDecodingResult(
            text: text.isEmpty ? nil : text,
            body: body,
            isNativelyEditable: body.isSupportedForEditing
        )
    }

    private static func isWithinCommentContentBudget(_ document: ProseMirrorDocument) -> Bool {
        var pendingNodes = document.content.map { (node: $0, depth: 1) }
        var remainingNodes = CommentContentDecodingLimits.maximumNodeCount
        var remainingText = CommentContentDecodingLimits.maximumAggregateTextLength

        while let entry = pendingNodes.popLast() {
            remainingNodes -= 1
            guard remainingNodes >= 0, entry.depth <= CommentContentDecodingLimits.maximumDepth else {
                return false
            }

            if let text = entry.node.text {
                guard text.count <= CommentContentDecodingLimits.maximumTextLength else { return false }
                remainingText -= text.count
                guard remainingText >= 0 else { return false }
            }

            let children = entry.node.content ?? []
            guard children.count <= CommentContentDecodingLimits.maximumChildrenPerNode else { return false }
            pendingNodes.append(contentsOf: children.map { (node: $0, depth: entry.depth + 1) })
        }
        return true
    }
}

nonisolated private struct CommentContentDecodingResult {
    let text: String?
    let body: CommentBody?
    let isNativelyEditable: Bool
}

nonisolated enum CommentContentDecodingLimits {
    static let maximumDepth = 64
    static let maximumChildrenPerNode = 256
    static let maximumNodeCount = 10_000
    static let maximumTextLength = 100_000
    static let maximumAggregateTextLength = 500_000
}
