import Foundation
import Testing
@testable import docmostly

struct EngagementEndpointTests {
    @Test func buildsPageDiscoveryRequests() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))

        let breadcrumbs = try Endpoint.pageBreadcrumbs(pageId: "page-1").urlRequest(baseURL: baseURL)
        #expect(breadcrumbs.url?.absoluteString == "https://docs.example.com/api/pages/breadcrumbs")
        #expect(try jsonBody(breadcrumbs)["pageId"] as? String == "page-1")

        let recent = try Endpoint.recentPages(spaceId: "space-1", cursor: "cursor-1", limit: 15)
            .urlRequest(baseURL: baseURL)
        #expect(recent.url?.absoluteString == "https://docs.example.com/api/pages/recent")
        let recentBody = try jsonBody(recent)
        #expect(recentBody["spaceId"] as? String == "space-1")
        #expect(recentBody["cursor"] as? String == "cursor-1")
        #expect(recentBody["limit"] as? Int == 15)
    }

    @Test func buildsFavoriteRequests() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))

        let favorites = try Endpoint.favorites(type: .page, spaceId: "space-1", cursor: "cursor-1", limit: 10)
            .urlRequest(baseURL: baseURL)
        #expect(favorites.url?.absoluteString == "https://docs.example.com/api/favorites")
        let favoritesBody = try jsonBody(favorites)
        #expect(favoritesBody["type"] as? String == "page")
        #expect(favoritesBody["spaceId"] as? String == "space-1")
        #expect(favoritesBody["cursor"] as? String == "cursor-1")
        #expect(favoritesBody["limit"] as? Int == 10)

        let ids = try Endpoint.favoriteIds(type: .page, spaceId: "space-1").urlRequest(baseURL: baseURL)
        #expect(ids.url?.absoluteString == "https://docs.example.com/api/favorites/ids")
        let idsBody = try jsonBody(ids)
        #expect(idsBody["type"] as? String == "page")
        #expect(idsBody["spaceId"] as? String == "space-1")

        let add = try Endpoint.addFavorite(type: .page, pageId: "page-1", spaceId: nil, templateId: nil)
            .urlRequest(baseURL: baseURL)
        #expect(add.url?.absoluteString == "https://docs.example.com/api/favorites/add")
        let addBody = try jsonBody(add)
        #expect(addBody["type"] as? String == "page")
        #expect(addBody["pageId"] as? String == "page-1")

        let remove = try Endpoint.removeFavorite(type: .space, pageId: nil, spaceId: "space-1", templateId: nil)
            .urlRequest(baseURL: baseURL)
        #expect(remove.url?.absoluteString == "https://docs.example.com/api/favorites/remove")
        let removeBody = try jsonBody(remove)
        #expect(removeBody["type"] as? String == "space")
        #expect(removeBody["spaceId"] as? String == "space-1")
    }

    @Test func buildsNotificationRequests() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))

        let list = try Endpoint.notifications(type: .direct, cursor: "cursor-1", limit: 25)
            .urlRequest(baseURL: baseURL)
        #expect(list.url?.absoluteString == "https://docs.example.com/api/notifications")
        let listBody = try jsonBody(list)
        #expect(listBody["type"] as? String == "direct")
        #expect(listBody["cursor"] as? String == "cursor-1")
        #expect(listBody["limit"] as? Int == 25)

        let count = try Endpoint.unreadNotificationCount.urlRequest(baseURL: baseURL)
        #expect(count.url?.absoluteString == "https://docs.example.com/api/notifications/unread-count")
        #expect(count.httpBody == nil)

        let markRead = try Endpoint.markNotificationsRead(notificationIds: ["notification-1", "notification-2"])
            .urlRequest(baseURL: baseURL)
        #expect(markRead.url?.absoluteString == "https://docs.example.com/api/notifications/mark-read")
        #expect(try jsonBody(markRead)["notificationIds"] as? [String] == ["notification-1", "notification-2"])

        let markAll = try Endpoint.markAllNotificationsRead.urlRequest(baseURL: baseURL)
        #expect(markAll.url?.absoluteString == "https://docs.example.com/api/notifications/mark-all-read")
        #expect(markAll.httpBody == nil)
    }

    @Test func buildsLabelRequests() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))

        let pageLabels = try Endpoint.pageLabels(pageId: "page-1").urlRequest(baseURL: baseURL)
        #expect(pageLabels.url?.absoluteString == "https://docs.example.com/api/pages/labels")
        #expect(try jsonBody(pageLabels)["pageId"] as? String == "page-1")

        let workspaceLabels = try Endpoint.workspaceLabels(type: .page, query: "prod", cursor: "cursor-1", limit: 20)
            .urlRequest(baseURL: baseURL)
        #expect(workspaceLabels.url?.absoluteString == "https://docs.example.com/api/labels")
        let workspaceBody = try jsonBody(workspaceLabels)
        #expect(workspaceBody["type"] as? String == "page")
        #expect(workspaceBody["query"] as? String == "prod")
        #expect(workspaceBody["cursor"] as? String == "cursor-1")
        #expect(workspaceBody["limit"] as? Int == 20)

        let add = try Endpoint.addPageLabels(pageId: "page-1", names: ["release", "ios"])
            .urlRequest(baseURL: baseURL)
        #expect(add.url?.absoluteString == "https://docs.example.com/api/pages/labels/add")
        let addBody = try jsonBody(add)
        #expect(addBody["pageId"] as? String == "page-1")
        #expect(addBody["names"] as? [String] == ["release", "ios"])

        let remove = try Endpoint.removePageLabel(pageId: "page-1", labelId: "label-1")
            .urlRequest(baseURL: baseURL)
        #expect(remove.url?.absoluteString == "https://docs.example.com/api/pages/labels/remove")
        let removeBody = try jsonBody(remove)
        #expect(removeBody["pageId"] as? String == "page-1")
        #expect(removeBody["labelId"] as? String == "label-1")

        let pages = try Endpoint.labelPages(labelId: "label-1", spaceId: "space-1", query: "road", limit: 30)
            .urlRequest(baseURL: baseURL)
        #expect(pages.url?.absoluteString == "https://docs.example.com/api/labels/pages")
        let pagesBody = try jsonBody(pages)
        #expect(pagesBody["labelId"] as? String == "label-1")
        #expect(pagesBody["spaceId"] as? String == "space-1")
        #expect(pagesBody["query"] as? String == "road")
        #expect(pagesBody["limit"] as? Int == 30)
    }

    @Test func buildsWatcherRequests() throws {
        let baseURL = try #require(URL(string: "https://docs.example.com"))

        let pageWatch = try Endpoint.watchPage(pageId: "page-1").urlRequest(baseURL: baseURL)
        #expect(pageWatch.url?.absoluteString == "https://docs.example.com/api/pages/watch")
        #expect(try jsonBody(pageWatch)["pageId"] as? String == "page-1")

        let pageUnwatch = try Endpoint.unwatchPage(pageId: "page-1").urlRequest(baseURL: baseURL)
        #expect(pageUnwatch.url?.absoluteString == "https://docs.example.com/api/pages/unwatch")
        #expect(try jsonBody(pageUnwatch)["pageId"] as? String == "page-1")

        let pageStatus = try Endpoint.pageWatchStatus(pageId: "page-1").urlRequest(baseURL: baseURL)
        #expect(pageStatus.url?.absoluteString == "https://docs.example.com/api/pages/watch-status")
        #expect(try jsonBody(pageStatus)["pageId"] as? String == "page-1")

        let watchedSpaceIds = try Endpoint.watchedSpaceIds.urlRequest(baseURL: baseURL)
        #expect(watchedSpaceIds.url?.absoluteString == "https://docs.example.com/api/spaces/watched-ids")
        #expect(watchedSpaceIds.httpBody == nil)

        let spaceWatch = try Endpoint.watchSpace(spaceId: "space-1").urlRequest(baseURL: baseURL)
        #expect(spaceWatch.url?.absoluteString == "https://docs.example.com/api/spaces/watch")
        #expect(try jsonBody(spaceWatch)["spaceId"] as? String == "space-1")

        let spaceStatus = try Endpoint.spaceWatchStatus(spaceId: "space-1").urlRequest(baseURL: baseURL)
        #expect(spaceStatus.url?.absoluteString == "https://docs.example.com/api/spaces/watch-status")
        #expect(try jsonBody(spaceStatus)["spaceId"] as? String == "space-1")
    }

    private func jsonBody(_ request: URLRequest) throws -> [String: Any] {
        let body = try #require(request.httpBody)
        return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }
}
