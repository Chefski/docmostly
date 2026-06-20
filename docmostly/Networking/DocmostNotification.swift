import Foundation

nonisolated struct DocmostNotification: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let userId: String
    let workspaceId: String
    let type: DocmostNotificationType
    let actorId: String?
    let pageId: String?
    let spaceId: String?
    let commentId: String?
    let data: [String: ProseMirrorJSONValue]?
    let readAt: Date?
    let emailedAt: Date?
    let archivedAt: Date?
    let createdAt: Date?
    let actor: DocmostNotificationActor?
    let page: DocmostNotificationPage?
    let space: DocmostNotificationSpace?
    let comment: DocmostComment?

    var isUnread: Bool {
        readAt == nil
    }
}
