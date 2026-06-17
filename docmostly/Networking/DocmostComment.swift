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
    }

    private static func decodeContent(from container: KeyedDecodingContainer<CodingKeys>) -> String? {
        if let content = try? container.decodeIfPresent(String.self, forKey: .content) {
            return content
        }

        guard let document = try? container.decodeIfPresent(CommentContentNode.self, forKey: .content) else {
            return nil
        }

        let text = document.plainText
        return text.isEmpty ? nil : text
    }
}

nonisolated private struct CommentContentNode: Decodable {
    let text: String?
    let content: [CommentContentNode]?

    var plainText: String {
        var parts: [String] = []
        if let text, text.isEmpty == false {
            parts.append(text)
        }
        parts.append(contentsOf: content?.map(\.plainText).filter { $0.isEmpty == false } ?? [])
        return parts.joined(separator: " ")
    }
}
