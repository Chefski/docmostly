import Foundation
import Observation

@MainActor
@Observable
final class NotificationListViewModel {
    private static let pageSize = 30

    private var pages = CursorPageAccumulator<DocmostNotification>()
    private(set) var locallyReadIDs: Set<String> = []
    @ObservationIgnored private var loadRequestID: UUID?

    var selectedType: NotificationListType = .all
    var selectedFilter: NotificationFilter = .all
    var isLoading = false
    var isLoadingNextPage = false
    var isMarkingAllRead = false
    var markingReadIDs: Set<String> = []
    var errorMessage: String?
    var nextPageErrorMessage: String?

    var notifications: [DocmostNotification] {
        pages.items
    }

    var visibleNotifications: [DocmostNotification] {
        switch selectedFilter {
        case .all:
            notifications
        case .unread:
            notifications.filter(isUnread)
        }
    }

    var sections: [NotificationSectionGroup] {
        let grouped = Dictionary(grouping: visibleNotifications) {
            NotificationTimeSection.section(for: $0.createdAt)
        }
        return NotificationTimeSection.allCases.compactMap { section in
            guard let notifications = grouped[section], notifications.isEmpty == false else { return nil }
            return NotificationSectionGroup(section: section, notifications: notifications)
        }
    }

    var hasNextPage: Bool {
        pages.hasNextPage
    }

    func isUnread(_ notification: DocmostNotification) -> Bool {
        notification.isUnread && locallyReadIDs.contains(notification.id) == false
    }

    func load(appState: AppState, store: NotificationStore) async {
        let requestID = UUID()
        let requestedType = selectedType
        loadRequestID = requestID
        isLoading = true
        errorMessage = nil
        nextPageErrorMessage = nil
        defer {
            if loadRequestID == requestID {
                isLoading = false
            }
        }

        async let loadedNotifications = captureLoad {
            try await appState.loadNotifications(type: requestedType, limit: Self.pageSize)
        }
        async let loadedUnreadCount = captureLoad {
            try await appState.loadUnreadNotificationCount()
        }

        let notificationOutcome = await loadedNotifications
        let unreadCountOutcome = await loadedUnreadCount
        guard Task.isCancelled == false, loadRequestID == requestID, selectedType == requestedType else { return }

        if let response = notificationOutcome.value {
            applyInitialPage(response)
        }
        if let count = unreadCountOutcome.value {
            store.reconcile(unreadCount: count)
        }
        errorMessage = notificationOutcome.errorMessage
        if notificationOutcome.errorMessage == nil, let unreadError = unreadCountOutcome.errorMessage {
            store.recordRefreshError(unreadError)
        }
    }

    func loadNextPage(appState: AppState) async {
        guard isLoading == false, isLoadingNextPage == false, let cursor = pages.nextCursor else { return }
        let requestedType = selectedType
        isLoadingNextPage = true
        nextPageErrorMessage = nil
        defer { isLoadingNextPage = false }

        do {
            let response = try await appState.loadNotifications(
                type: requestedType,
                cursor: cursor,
                limit: Self.pageSize
            )
            guard Task.isCancelled == false, selectedType == requestedType else { return }
            applyNextPage(response, requestedCursor: cursor)
        } catch is CancellationError {
            return
        } catch {
            nextPageErrorMessage = error.localizedDescription
        }
    }

    func markRead(
        _ notification: DocmostNotification,
        appState: AppState,
        store: NotificationStore
    ) async {
        await markRead(notification, store: store) {
            try await appState.markNotificationsRead(notificationIds: [notification.id])
        }
        if errorMessage == nil {
            await store.refreshUnreadCount(appState: appState)
        }
    }

    func markAllRead(appState: AppState, store: NotificationStore) async {
        await markAllRead(store: store) {
            try await appState.markAllNotificationsRead()
        }
        if errorMessage == nil {
            await load(appState: appState, store: store)
        }
    }

    func applyInitialPage(_ response: PaginatedResponse<DocmostNotification>) {
        pages.replace(with: response)
        locallyReadIDs = locallyReadIDs.filter { id in
            response.items.contains { $0.id == id && $0.isUnread }
        }
    }

    func applyNextPage(
        _ response: PaginatedResponse<DocmostNotification>,
        requestedCursor: String
    ) {
        pages.append(response, requestedCursor: requestedCursor)
    }

    func markRead(
        _ notification: DocmostNotification,
        store: NotificationStore,
        operation: () async throws -> Void
    ) async {
        guard isUnread(notification) else { return }
        guard markingReadIDs.insert(notification.id).inserted else { return }

        let previousUnreadCount = store.applyOptimisticRead()
        locallyReadIDs.insert(notification.id)
        errorMessage = nil
        defer { markingReadIDs.remove(notification.id) }

        do {
            try await operation()
        } catch is CancellationError {
            locallyReadIDs.remove(notification.id)
            store.restoreUnreadCount(previousUnreadCount)
        } catch {
            locallyReadIDs.remove(notification.id)
            store.restoreUnreadCount(previousUnreadCount)
            errorMessage = error.localizedDescription
        }
    }

    func markAllRead(
        store: NotificationStore,
        operation: () async throws -> Void
    ) async {
        guard isMarkingAllRead == false else { return }

        isMarkingAllRead = true
        let previousLocallyReadIDs = locallyReadIDs
        let previousUnreadCount = store.applyOptimisticMarkAllRead()
        locallyReadIDs.formUnion(notifications.lazy.filter(\.isUnread).map(\.id))
        errorMessage = nil
        defer { isMarkingAllRead = false }

        do {
            try await operation()
        } catch is CancellationError {
            locallyReadIDs = previousLocallyReadIDs
            store.restoreUnreadCount(previousUnreadCount)
        } catch {
            locallyReadIDs = previousLocallyReadIDs
            store.restoreUnreadCount(previousUnreadCount)
            errorMessage = error.localizedDescription
        }
    }

    private func captureLoad<Value: Sendable>(
        _ operation: () async throws -> Value
    ) async -> NotificationLoadOutcome<Value> {
        do {
            return NotificationLoadOutcome(value: try await operation(), errorMessage: nil)
        } catch is CancellationError {
            return NotificationLoadOutcome(value: nil, errorMessage: nil)
        } catch {
            return NotificationLoadOutcome(value: nil, errorMessage: error.localizedDescription)
        }
    }
}

nonisolated struct NotificationSectionGroup: Identifiable, Sendable {
    let section: NotificationTimeSection
    let notifications: [DocmostNotification]

    var id: NotificationTimeSection { section }
}

private struct NotificationLoadOutcome<Value: Sendable>: Sendable {
    let value: Value?
    let errorMessage: String?
}
