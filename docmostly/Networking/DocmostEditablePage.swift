import Foundation

nonisolated struct DocmostEditablePage: Decodable, Identifiable, Sendable {
    let id: String
    let slugId: String
    let title: String
    let content: ProseMirrorDocument?
    let icon: String?
    let spaceId: String
    let createdAt: Date?
    let updatedAt: Date?
    let permissions: DocmostPagePermissions?
    let creator: DocmostPagePerson?
    let lastUpdatedBy: DocmostPagePerson?

    init(
        id: String,
        slugId: String,
        title: String,
        content: ProseMirrorDocument?,
        icon: String?,
        spaceId: String,
        createdAt: Date? = nil,
        updatedAt: Date?,
        permissions: DocmostPagePermissions?,
        creator: DocmostPagePerson? = nil,
        lastUpdatedBy: DocmostPagePerson?
    ) {
        self.id = id
        self.slugId = slugId
        self.title = title
        self.content = content
        self.icon = icon
        self.spaceId = spaceId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.permissions = permissions
        self.creator = creator
        self.lastUpdatedBy = lastUpdatedBy
    }
}

nonisolated extension DocmostEditablePage {
    private enum CodingKeys: String, CodingKey {
        case id
        case slugId
        case title
        case content
        case icon
        case spaceId
        case createdAt
        case updatedAt
        case permissions
        case creator
        case lastUpdatedBy
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        slugId = try container.decode(String.self, forKey: .slugId)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        content = try container.decodeIfPresent(ProseMirrorDocument.self, forKey: .content)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        spaceId = try container.decode(String.self, forKey: .spaceId)
        createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt)
        permissions = try container.decodeIfPresent(DocmostPagePermissions.self, forKey: .permissions)
        creator = try container.decodeIfPresent(DocmostPagePerson.self, forKey: .creator)
        lastUpdatedBy = try container.decodeIfPresent(DocmostPagePerson.self, forKey: .lastUpdatedBy)
    }
}
