import Foundation

nonisolated struct DocmostPageHistory: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let pageId: String
    let title: String
    let content: ProseMirrorDocument?
    let slug: String?
    let icon: String?
    let coverPhoto: String?
    let version: Int?
    let lastUpdatedById: String?
    let workspaceId: String?
    let createdAt: Date?
    let updatedAt: Date?
    let lastUpdatedBy: DocmostPagePerson?
    let contributors: [DocmostPagePerson]?
}
