import Foundation
import Testing
@testable import DocmostlyMac

@MainActor
struct EngagementParityTests {
    @Test func paginationDeduplicatesStableIDsAndStopsRepeatedCursors() {
        var accumulator = CursorPageAccumulator<TestItem>()
        accumulator.replace(with: PaginatedResponse(
            items: [TestItem(id: "1"), TestItem(id: "2")],
            meta: paginationMeta(nextCursor: "cursor-2")
        ))

        accumulator.append(
            PaginatedResponse(
                items: [TestItem(id: "2"), TestItem(id: "3")],
                meta: paginationMeta(nextCursor: "cursor-2")
            ),
            requestedCursor: "cursor-2"
        )

        #expect(accumulator.items.map(\.id) == ["1", "2", "3"])
        #expect(accumulator.hasNextPage == false)
    }

    @Test func unreadCountReconcilesAndClampsServerValues() {
        let store = NotificationStore()

        store.reconcile(unreadCount: 7)
        #expect(store.unreadCount == 7)

        store.reconcile(unreadCount: -1)
        #expect(store.unreadCount == 0)
    }

    @Test func optimisticReadUpdatesCountAndRollsBackAfterFailure() async {
        let notification = makeNotification(id: "notification-1")
        let viewModel = NotificationListViewModel()
        let store = NotificationStore()
        store.reconcile(unreadCount: 2)
        viewModel.applyInitialPage(notificationResponse(items: [notification]))

        await viewModel.markRead(notification, store: store) { }

        #expect(viewModel.isUnread(notification) == false)
        #expect(store.unreadCount == 1)

        let failingNotification = makeNotification(id: "notification-2")
        viewModel.applyInitialPage(notificationResponse(items: [failingNotification]))
        await viewModel.markRead(failingNotification, store: store) {
            throw TestFailure.failed
        }

        #expect(viewModel.isUnread(failingNotification))
        #expect(store.unreadCount == 1)
        #expect(viewModel.errorMessage != nil)
    }

    @Test func markAllReadRollsBackLoadedRowsAndCount() async {
        let first = makeNotification(id: "notification-1")
        let second = makeNotification(id: "notification-2")
        let viewModel = NotificationListViewModel()
        let store = NotificationStore()
        store.reconcile(unreadCount: 4)
        viewModel.applyInitialPage(notificationResponse(items: [first, second]))

        await viewModel.markAllRead(store: store) {
            throw TestFailure.failed
        }

        #expect(viewModel.isUnread(first))
        #expect(viewModel.isUnread(second))
        #expect(store.unreadCount == 4)
    }

    @Test func commentNotificationCarriesCommentThroughAppNavigation() throws {
        let notification = makeNotification(
            id: "notification-1",
            type: .commentCreated,
            commentID: "comment-1"
        )
        let target = try #require(PageOpenTarget(notification: notification))
        let appState = makeAppState()

        appState.openPage(target)

        #expect(target.commentId == "comment-1")
        #expect(appState.selectedPageID == "roadmap")
        #expect(appState.selectedSpaceID == "space-1")
        #expect(appState.selectedCommentID == "comment-1")
    }

    @Test func favoriteRemovalStaysRemovedAfterSuccessAndRollsBackAfterFailure() async {
        let first = pageFavorite(id: "favorite-page")
        let second = spaceFavorite(id: "favorite-space", name: "Product")
        let viewModel = FavoritesViewModel()
        viewModel.applyInitialPage(favoriteResponse(items: [first, second]))

        await viewModel.remove(first) { }
        #expect(viewModel.favorites.map(\.id) == [second.id])

        viewModel.applyInitialPage(favoriteResponse(items: [first, second]))
        await viewModel.remove(first) {
            throw TestFailure.failed
        }

        #expect(viewModel.favorites.map(\.id) == [first.id, second.id])
        #expect(viewModel.errorMessage != nil)
    }

    @Test func favoriteSectionsRepresentSpacesPagesAndTemplates() {
        let zulu = spaceFavorite(id: "favorite-zulu", name: "Zulu")
        let alpha = spaceFavorite(id: "favorite-alpha", name: "Alpha")
        let page = pageFavorite(id: "favorite-page")
        let template = templateFavorite(id: "favorite-template")
        let viewModel = FavoritesViewModel()
        viewModel.applyInitialPage(favoriteResponse(items: [zulu, page, template, alpha]))

        #expect(viewModel.sections.map(\.type) == [.space, .page, .template])
        #expect(viewModel.sections.first?.favorites.map(\.title) == ["Alpha", "Zulu"])
        #expect(PageOpenTarget(favorite: page)?.slugId == "roadmap")
        #expect(zulu.targetID == "space-1")
        #expect(template.title == "Planning Template")
    }

    private func notificationResponse(
        items: [DocmostNotification]
    ) -> PaginatedResponse<DocmostNotification> {
        PaginatedResponse(items: items, meta: paginationMeta())
    }

    private func favoriteResponse(
        items: [DocmostFavorite]
    ) -> PaginatedResponse<DocmostFavorite> {
        PaginatedResponse(items: items, meta: paginationMeta())
    }

    private func paginationMeta(nextCursor: String? = nil) -> PaginationMeta {
        PaginationMeta(
            limit: 30,
            hasNextPage: nextCursor != nil,
            hasPrevPage: false,
            nextCursor: nextCursor,
            prevCursor: nil
        )
    }

    private func makeNotification(
        id: String,
        type: DocmostNotificationType = .pageUpdated,
        commentID: String? = nil
    ) -> DocmostNotification {
        DocmostNotification(
            id: id,
            userId: "user-1",
            workspaceId: "workspace-1",
            type: type,
            actorId: nil,
            pageId: "page-1",
            spaceId: "space-1",
            commentId: commentID,
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

    private func pageFavorite(id: String) -> DocmostFavorite {
        DocmostFavorite(
            id: id,
            userId: "user-1",
            pageId: "page-1",
            spaceId: nil,
            templateId: nil,
            type: .page,
            workspaceId: "workspace-1",
            createdAt: .now,
            page: DocmostFavoritePage(
                id: "page-1",
                slugId: "roadmap",
                title: "Roadmap",
                icon: nil,
                spaceId: "space-1"
            ),
            space: DocmostFavoriteSpace(id: "space-1", name: "Product", slug: "product", logo: nil),
            template: nil
        )
    }

    private func spaceFavorite(id: String, name: String) -> DocmostFavorite {
        DocmostFavorite(
            id: id,
            userId: "user-1",
            pageId: nil,
            spaceId: "space-1",
            templateId: nil,
            type: .space,
            workspaceId: "workspace-1",
            createdAt: .now,
            page: nil,
            space: DocmostFavoriteSpace(id: "space-1", name: name, slug: name.lowercased(), logo: nil),
            template: nil
        )
    }

    private func templateFavorite(id: String) -> DocmostFavorite {
        DocmostFavorite(
            id: id,
            userId: "user-1",
            pageId: nil,
            spaceId: nil,
            templateId: "template-1",
            type: .template,
            workspaceId: "workspace-1",
            createdAt: .now,
            page: nil,
            space: nil,
            template: DocmostFavoriteTemplate(
                id: "template-1",
                title: "Planning Template",
                description: nil,
                icon: nil,
                spaceId: nil
            )
        )
    }

    private func makeAppState() -> AppState {
        let suiteName = "Docmostly.EngagementParityTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        userDefaults.removePersistentDomain(forName: suiteName)
        return AppState(settingsStore: LocalSettingsStore(userDefaults: userDefaults))
    }

    private struct TestItem: Codable, Identifiable, Sendable {
        let id: String
    }

    private enum TestFailure: Error {
        case failed
    }
}
