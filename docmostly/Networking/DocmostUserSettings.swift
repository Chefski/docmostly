import Foundation

nonisolated struct DocmostUserSettings: Decodable, Hashable, Sendable {
    let preferences: DocmostUserPreferences?
    let notifications: DocmostUserNotificationSettings?
}

nonisolated struct DocmostUserPreferences: Decodable, Hashable, Sendable {
    let fullPageWidth: Bool?
    let pageEditMode: String?
    let editorToolbar: Bool?
}

nonisolated struct DocmostUserNotificationSettings: Decodable, Hashable, Sendable {
    let pageUpdated: Bool?
    let pageUserMention: Bool?
    let commentUserMention: Bool?
    let commentCreated: Bool?
    let commentResolved: Bool?

    private enum CodingKeys: String, CodingKey {
        case pageUpdated = "page.updated"
        case pageUserMention = "page.userMention"
        case commentUserMention = "comment.userMention"
        case commentCreated = "comment.created"
        case commentResolved = "comment.resolved"
    }
}
