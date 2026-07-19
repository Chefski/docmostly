import Foundation
import Testing
@testable import docmostly

@MainActor
struct NotificationListViewModelTests {
    @Test func defaultsToAllNotifications() {
        let viewModel = NotificationListViewModel()

        #expect(viewModel.selectedType == .all)
    }

    @Test func optimisticReadUpdatesCountAndLoadedRow() async {
        let notification = makeNotification(id: "notification-1")
        let viewModel = NotificationListViewModel()
        let store = NotificationStore()
        store.reconcile(unreadCount: 2)
        viewModel.applyInitialPage(response(items: [notification]))

        await viewModel.markRead(notification, store: store) { }

        #expect(viewModel.isUnread(notification) == false)
        #expect(store.unreadCount == 1)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func failedOptimisticReadRollsBackCountAndLoadedRow() async {
        let notification = makeNotification(id: "notification-1")
        let viewModel = NotificationListViewModel()
        let store = NotificationStore()
        store.reconcile(unreadCount: 2)
        viewModel.applyInitialPage(response(items: [notification]))

        await viewModel.markRead(notification, store: store) {
            throw EngagementTestError.failed
        }

        #expect(viewModel.isUnread(notification))
        #expect(store.unreadCount == 2)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func markAllReadRollsBackEveryLoadedRowOnFailure() async {
        let first = makeNotification(id: "notification-1")
        let second = makeNotification(id: "notification-2")
        let viewModel = NotificationListViewModel()
        let store = NotificationStore()
        store.reconcile(unreadCount: 4)
        viewModel.applyInitialPage(response(items: [first, second]))

        await viewModel.markAllRead(store: store) {
            throw EngagementTestError.failed
        }

        #expect(viewModel.isUnread(first))
        #expect(viewModel.isUnread(second))
        #expect(store.unreadCount == 4)
    }

    private func response(
        items: [DocmostNotification]
    ) -> PaginatedResponse<DocmostNotification> {
        PaginatedResponse(
            items: items,
            meta: PaginationMeta(
                limit: 30,
                hasNextPage: false,
                hasPrevPage: false,
                nextCursor: nil,
                prevCursor: nil
            )
        )
    }

    private func makeNotification(id: String) -> DocmostNotification {
        DocmostNotification(
            id: id,
            userId: "user-1",
            workspaceId: "workspace-1",
            type: .pageUpdated,
            actorId: nil,
            pageId: "page-1",
            spaceId: "space-1",
            commentId: nil,
            data: nil,
            readAt: nil,
            emailedAt: nil,
            archivedAt: nil,
            createdAt: .now,
            actor: nil,
            page: DocmostNotificationPage(id: "page-1", title: "Roadmap", slugId: "roadmap", icon: nil),
            space: DocmostNotificationSpace(id: "space-1", name: "Product", slug: "product"),
            comment: nil
        )
    }
}

private enum EngagementTestError: Error {
    case failed
}
