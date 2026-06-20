import Foundation

nonisolated struct AccountSettingsDraft: Equatable, Sendable {
    var name: String
    var email: String
    var fullPageWidth: Bool
    var pageEditMode: String
    var editorToolbar: Bool
    var notificationPageUpdates: Bool
    var notificationPageUserMention: Bool
    var notificationCommentUserMention: Bool
    var notificationCommentCreated: Bool
    var notificationCommentResolved: Bool

    private var originalUser: DocmostUser?

    init() {
        name = ""
        email = ""
        fullPageWidth = false
        pageEditMode = "edit"
        editorToolbar = true
        notificationPageUpdates = true
        notificationPageUserMention = true
        notificationCommentUserMention = true
        notificationCommentCreated = true
        notificationCommentResolved = true
        originalUser = nil
    }

    init(user: DocmostUser) {
        let preferences = user.settings?.preferences
        let notifications = user.settings?.notifications
        name = user.name
        email = user.email ?? ""
        fullPageWidth = preferences?.fullPageWidth ?? false
        pageEditMode = preferences?.pageEditMode ?? "edit"
        editorToolbar = preferences?.editorToolbar ?? true
        notificationPageUpdates = notifications?.pageUpdated ?? true
        notificationPageUserMention = notifications?.pageUserMention ?? true
        notificationCommentUserMention = notifications?.commentUserMention ?? true
        notificationCommentCreated = notifications?.commentCreated ?? true
        notificationCommentResolved = notifications?.commentResolved ?? true
        originalUser = user
    }

    var validationMessage: String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Name is required."
        }
        return nil
    }

    var canSave: Bool {
        validationMessage == nil && update().hasChanges
    }

    func update() -> UserUpdate {
        guard let originalUser else {
            return UserUpdate(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                fullPageWidth: fullPageWidth,
                pageEditMode: pageEditMode,
                editorToolbar: editorToolbar,
                notificationPageUpdates: notificationPageUpdates,
                notificationPageUserMention: notificationPageUserMention,
                notificationCommentUserMention: notificationCommentUserMention,
                notificationCommentCreated: notificationCommentCreated,
                notificationCommentResolved: notificationCommentResolved
            )
        }

        let original = AccountSettingsDraft(user: originalUser)
        return UserUpdate(
            name: changedString(name, original.name),
            fullPageWidth: changed(fullPageWidth, original.fullPageWidth),
            pageEditMode: changedString(pageEditMode, original.pageEditMode),
            editorToolbar: changed(editorToolbar, original.editorToolbar),
            notificationPageUpdates: changed(notificationPageUpdates, original.notificationPageUpdates),
            notificationPageUserMention: changed(notificationPageUserMention, original.notificationPageUserMention),
            notificationCommentUserMention: changed(
                notificationCommentUserMention,
                original.notificationCommentUserMention
            ),
            notificationCommentCreated: changed(notificationCommentCreated, original.notificationCommentCreated),
            notificationCommentResolved: changed(notificationCommentResolved, original.notificationCommentResolved)
        )
    }

    mutating func reset(to user: DocmostUser) {
        self = AccountSettingsDraft(user: user)
    }

    private func changed<Value: Equatable>(_ value: Value, _ original: Value) -> Value? {
        value == original ? nil : value
    }

    private func changedString(_ value: String, _ original: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == original ? nil : trimmed
    }
}
