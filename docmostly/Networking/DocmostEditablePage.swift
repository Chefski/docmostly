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
