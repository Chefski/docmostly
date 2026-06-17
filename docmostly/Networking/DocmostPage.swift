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
