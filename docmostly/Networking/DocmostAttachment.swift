import Foundation

nonisolated struct DocmostAttachment: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let fileName: String
    let filePath: String?
    let fileSize: Int?
    let fileExt: String?
    let mimeType: String?
    let type: String?
    let creatorId: String?
    let pageId: String?
    let spaceId: String?
    let workspaceId: String?
    let createdAt: Date?
    let updatedAt: Date?
    let deletedAt: Date?
}
