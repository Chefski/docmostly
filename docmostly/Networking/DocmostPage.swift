import Foundation

nonisolated struct DocmostPage: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let slugId: String
    let title: String
    let content: String?
    let icon: String?
    let coverPhoto: String?
    let parentPageId: String?
    let creatorId: String?
    let spaceId: String
    let workspaceId: String?
    let isLocked: Bool?
    let lastUpdatedById: String?
    let createdAt: Date?
    let updatedAt: Date?
    let deletedAt: Date?
    let position: String?
    let hasChildren: Bool?
    let permissions: DocmostPagePermissions?
    let creator: DocmostPagePerson?
    let lastUpdatedBy: DocmostPagePerson?
    let contributors: [DocmostPagePerson]?
    let space: DocmostPageSpace?
}

nonisolated extension DocmostPage {
    private enum CodingKeys: String, CodingKey {
        case id
        case slugId
        case title
        case content
        case icon
        case coverPhoto
        case parentPageId
        case creatorId
        case spaceId
        case workspaceId
        case isLocked
        case lastUpdatedById
        case createdAt
        case updatedAt
        case deletedAt
        case position
        case hasChildren
        case permissions
        case creator
        case lastUpdatedBy
        case contributors
        case space
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        slugId = try container.decode(String.self, forKey: .slugId)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        content = try container.decodeIfPresent(String.self, forKey: .content)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        coverPhoto = try container.decodeIfPresent(String.self, forKey: .coverPhoto)
        parentPageId = try container.decodeIfPresent(String.self, forKey: .parentPageId)
        creatorId = try container.decodeIfPresent(String.self, forKey: .creatorId)
        spaceId = try container.decode(String.self, forKey: .spaceId)
        workspaceId = try container.decodeIfPresent(String.self, forKey: .workspaceId)
        isLocked = try container.decodeIfPresent(Bool.self, forKey: .isLocked)
        lastUpdatedById = try container.decodeIfPresent(String.self, forKey: .lastUpdatedById)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
        position = try container.decodeIfPresent(String.self, forKey: .position)
        hasChildren = try container.decodeIfPresent(Bool.self, forKey: .hasChildren)
        permissions = try container.decodeIfPresent(DocmostPagePermissions.self, forKey: .permissions)
        creator = try container.decodeIfPresent(DocmostPagePerson.self, forKey: .creator)
        lastUpdatedBy = try container.decodeIfPresent(DocmostPagePerson.self, forKey: .lastUpdatedBy)
        contributors = try container.decodeIfPresent([DocmostPagePerson].self, forKey: .contributors)
        space = try container.decodeIfPresent(DocmostPageSpace.self, forKey: .space)
    }
}
