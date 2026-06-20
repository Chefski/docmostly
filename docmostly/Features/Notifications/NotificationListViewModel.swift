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

        do {
            let response = try await appState.loadNotifications(type: selectedType, limit: 50)
            notifications = response.items
            unreadCount = try await appState.loadUnreadNotificationCount()
        } catch {
            errorMessage = error.localizedDescription
        }
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
}
