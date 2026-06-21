import Foundation
import Observation

@MainActor
@Observable
final class NotificationListViewModel {
    var notifications: [DocmostNotification] = []
    var selectedType: NotificationListType = .all
    var unreadCount = 0
    var isLoading = false
    var isMarkingAllRead = false
    var markingReadIDs: Set<String> = []
    var errorMessage: String?

    func load(appState: AppState) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        async let loadedNotifications = captureLoad {
            try await appState.loadNotifications(type: selectedType, limit: 50)
        }
        async let loadedUnreadCount = captureLoad {
            try await appState.loadUnreadNotificationCount()
        }

        let notificationOutcome = await loadedNotifications
        let unreadCountOutcome = await loadedUnreadCount

        if let response = notificationOutcome.value {
            notifications = response.items
        }
        if let count = unreadCountOutcome.value {
            unreadCount = count
        }
        errorMessage = notificationOutcome.errorMessage ?? unreadCountOutcome.errorMessage
    }

    func markRead(_ notification: DocmostNotification, appState: AppState) async {
        guard notification.isUnread else { return }
        guard markingReadIDs.contains(notification.id) == false else { return }

        markingReadIDs.insert(notification.id)
        errorMessage = nil
        defer {
            markingReadIDs.remove(notification.id)
        }

        do {
            try await appState.markNotificationsRead(notificationIds: [notification.id])
            await load(appState: appState)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func markAllRead(appState: AppState) async {
        guard isMarkingAllRead == false else { return }

        isMarkingAllRead = true
        errorMessage = nil
        defer { isMarkingAllRead = false }

        do {
            try await appState.markAllNotificationsRead()
            await load(appState: appState)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func captureLoad<Value: Sendable>(
        _ operation: () async throws -> Value
    ) async -> NotificationLoadOutcome<Value> {
        do {
            return NotificationLoadOutcome(value: try await operation(), errorMessage: nil)
        } catch {
            return NotificationLoadOutcome(value: nil, errorMessage: error.localizedDescription)
        }
    }
}

private struct NotificationLoadOutcome<Value: Sendable>: Sendable {
    let value: Value?
    let errorMessage: String?
}
