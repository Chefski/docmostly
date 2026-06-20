import Foundation
import Testing
@testable import docmostly

struct EngagementDecodingTests {
    @Test func decodesFavorites() throws {
        let data = Data("""
        {
          "data": {
            "items": [
              {
                "id": "favorite-1",
                "userId": "user-1",
                "pageId": "page-1",
                "spaceId": null,
                "templateId": null,
                "type": "page",
                "workspaceId": "workspace-1",
                "createdAt": "2026-06-20T09:00:00.000Z",
                "page": {
                  "id": "page-1",
                  "slugId": "roadmap",
                  "title": "Roadmap",
                  "content": null,
                  "icon": "📄",
                  "coverPhoto": null,
                  "parentPageId": null,
                  "creatorId": "user-1",
                  "spaceId": "space-1",
                  "workspaceId": "workspace-1",
                  "isLocked": false,
                  "lastUpdatedById": "user-1",
                  "createdAt": "2026-06-20T08:00:00.000Z",
                  "updatedAt": "2026-06-20T08:30:00.000Z",
                  "deletedAt": null,
                  "position": "a0",
                  "hasChildren": true
                }
              }
            ],
            "meta": {
              "limit": 15,
              "hasNextPage": false,
              "hasPrevPage": false,
              "nextCursor": null,
              "prevCursor": null
            }
          },
          "success": true,
          "status": 200
        }
        """.utf8)

        let envelope = try DocmostJSONDecoder.make().decode(
            APIEnvelope<PaginatedResponse<DocmostFavorite>>.self,
            from: data
        )
        let favorite = try #require(envelope.data.items.first)

        #expect(favorite.id == "favorite-1")
        #expect(favorite.type == .page)
        #expect(favorite.page?.title == "Roadmap")
        #expect(favorite.createdAt?.formatted(.iso8601.year().month().day()) == "2026-06-20")
    }

    @Test func decodesNotifications() throws {
        let data = Data("""
        {
          "data": {
            "items": [
              {
                "id": "notification-1",
                "userId": "user-1",
                "workspaceId": "workspace-1",
                "type": "page.updated",
                "actorId": "actor-1",
                "pageId": "page-1",
                "spaceId": "space-1",
                "commentId": null,
                "data": { "title": "Roadmap" },
                "readAt": null,
                "emailedAt": null,
                "archivedAt": null,
                "createdAt": "2026-06-20T09:00:00.000Z",
                "actor": {
                  "id": "actor-1",
                  "name": "Ada Lovelace",
                  "email": "ada@example.com",
                  "avatarUrl": null,
                  "role": "member",
                  "locale": "en",
                  "deactivatedAt": null,
                  "lastActiveAt": "2026-06-20T08:59:00.000Z",
                  "createdAt": "2026-01-01T00:00:00.000Z"
                },
                "page": {
                  "id": "page-1",
                  "slugId": "roadmap",
                  "title": "Roadmap",
                  "content": null,
                  "icon": null,
                  "coverPhoto": null,
                  "parentPageId": null,
                  "creatorId": "actor-1",
                  "spaceId": "space-1",
                  "workspaceId": "workspace-1",
                  "isLocked": false,
                  "lastUpdatedById": "actor-1",
                  "createdAt": "2026-06-20T08:00:00.000Z",
                  "updatedAt": "2026-06-20T08:30:00.000Z",
                  "deletedAt": null,
                  "position": "a0",
                  "hasChildren": false
                }
              }
            ],
            "meta": {
              "limit": 15,
              "hasNextPage": false,
              "hasPrevPage": false,
              "nextCursor": null,
              "prevCursor": null
            }
          },
          "success": true,
          "status": 200
        }
        """.utf8)

        let envelope = try DocmostJSONDecoder.make().decode(
            APIEnvelope<PaginatedResponse<DocmostNotification>>.self,
            from: data
        )
        let notification = try #require(envelope.data.items.first)

        #expect(notification.id == "notification-1")
        #expect(notification.type == .pageUpdated)
        #expect(notification.isUnread == true)
        #expect(notification.actor?.name == "Ada Lovelace")
        #expect(notification.page?.title == "Roadmap")
    }

    @Test func decodesLabelsAndLabeledPages() throws {
        let labelsData = Data("""
        {
          "data": {
            "items": [
              {
                "id": "label-1",
                "name": "release",
                "type": "page",
                "workspaceId": "workspace-1",
                "createdAt": "2026-06-20T09:00:00.000Z",
                "updatedAt": "2026-06-20T09:30:00.000Z"
              }
            ],
            "meta": {
              "limit": 25,
              "hasNextPage": false,
              "hasPrevPage": false,
              "nextCursor": null,
              "prevCursor": null
            }
          },
          "success": true,
          "status": 200
        }
        """.utf8)

        let labelsEnvelope = try DocmostJSONDecoder.make().decode(
            APIEnvelope<PaginatedResponse<DocmostLabel>>.self,
            from: labelsData
        )
        let label = try #require(labelsEnvelope.data.items.first)
        #expect(label.id == "label-1")
        #expect(label.type == .page)

        let pagesData = Data("""
        {
          "data": {
            "items": [
              {
                "id": "page-1",
                "slugId": "roadmap",
                "title": "Roadmap",
                "icon": "📄",
                "spaceId": "space-1",
                "createdAt": "2026-06-20T08:00:00.000Z",
                "updatedAt": "2026-06-20T08:30:00.000Z",
                "space": { "id": "space-1", "name": "Product", "slug": "product", "logo": null },
                "creator": { "id": "user-1", "name": "Ada Lovelace", "avatarUrl": null },
                "labels": [{ "id": "label-1", "name": "release" }]
              }
            ],
            "meta": {
              "limit": 25,
              "hasNextPage": false,
              "hasPrevPage": false,
              "nextCursor": null,
              "prevCursor": null
            }
          },
          "success": true,
          "status": 200
        }
        """.utf8)

        let pagesEnvelope = try DocmostJSONDecoder.make().decode(
            APIEnvelope<PaginatedResponse<DocmostLabeledPage>>.self,
            from: pagesData
        )
        let page = try #require(pagesEnvelope.data.items.first)
        #expect(page.title == "Roadmap")
        #expect(page.space?.name == "Product")
        #expect(page.labels.map(\.name) == ["release"])
    }

    @Test func decodesWatchStatusAndUnreadCount() throws {
        let watchStatusData = Data("""
        {
          "data": { "watching": true },
          "success": true,
          "status": 200
        }
        """.utf8)
        let watchStatus = try DocmostJSONDecoder.make().decode(
            APIEnvelope<WatchStatusResponse>.self,
            from: watchStatusData
        )
        #expect(watchStatus.data.watching == true)

        let countData = Data("""
        {
          "data": { "count": 3 },
          "success": true,
          "status": 200
        }
        """.utf8)
        let unreadCount = try DocmostJSONDecoder.make().decode(
            APIEnvelope<UnreadNotificationCountResponse>.self,
            from: countData
        )
        #expect(unreadCount.data.count == 3)
    }
}
