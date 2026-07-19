import Foundation
import Testing
@testable import docmostly

@MainActor
struct NotificationDeepLinkRoutingTests {
    @Test func commentNotificationCarriesCommentThroughAppNavigation() throws {
        let notification = DocmostNotification(
            id: "notification-1",
            userId: "user-1",
            workspaceId: "workspace-1",
            type: .commentCreated,
            actorId: "user-2",
            pageId: "page-1",
            spaceId: "space-1",
            commentId: "comment-1",
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
        let target = try #require(PageOpenTarget(notification: notification))
        let appState = makeAppState()

        appState.openPage(target)

        #expect(target.commentId == "comment-1")
        #expect(appState.selectedPageID == "roadmap")
        #expect(appState.selectedSpaceID == "space-1")
        #expect(appState.selectedCommentID == "comment-1")
    }

    private func makeAppState() -> AppState {
        let suiteName = "Docmostly.NotificationDeepLinkRoutingTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName) ?? .standard
        userDefaults.removePersistentDomain(forName: suiteName)
        return AppState(settingsStore: LocalSettingsStore(userDefaults: userDefaults))
    }
}
