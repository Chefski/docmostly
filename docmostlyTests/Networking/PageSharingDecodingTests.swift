import Foundation
import Testing
@testable import docmostly

struct PageSharingDecodingTests {
    @Test func decodesShareForPageResponse() throws {
        let data = Data("""
        {
          "data": {
            "id": "share-1",
            "key": "public-key",
            "pageId": "page-1",
            "includeSubPages": true,
            "searchIndexing": false,
            "creatorId": "user-1",
            "spaceId": "space-1",
            "workspaceId": "workspace-1",
            "level": 0,
            "sharedPage": {
              "id": "page-1",
              "slugId": "roadmap",
              "title": "Roadmap",
              "icon": null
            },
            "createdAt": "2026-07-04T09:00:00.000Z",
            "updatedAt": "2026-07-04T09:30:00.000Z",
            "deletedAt": null
          },
          "success": true,
          "status": 200
        }
        """.utf8)

        let envelope = try DocmostJSONDecoder.make().decode(
            APIEnvelope<DocmostPageShare>.self,
            from: data
        )

        #expect(envelope.data.id == "share-1")
        #expect(envelope.data.isDirectShare)
        #expect(envelope.data.includeSubPages)
        #expect(envelope.data.searchIndexing == false)
        #expect(envelope.data.sharedPage?.title == "Roadmap")
    }

    @Test func decodesMissingShareForPageResponse() throws {
        let data = Data("""
        {
          "data": null,
          "success": true,
          "status": 200
        }
        """.utf8)

        let envelope = try DocmostJSONDecoder.make().decode(
            APIEnvelope<DocmostPageShare?>.self,
            from: data
        )

        #expect(envelope.data == nil)
    }

    @Test func decodesPageRestrictionInfoResponse() throws {
        let data = Data("""
        {
          "data": {
            "restrictionId": "restriction-1",
            "hasDirectRestriction": false,
            "hasInheritedRestriction": true,
            "inheritedFrom": {
              "id": "page-parent",
              "slugId": "parent",
              "title": "Parent",
              "icon": null
            },
            "userAccess": {
              "canView": true,
              "canEdit": false,
              "canManage": false
            }
          },
          "success": true,
          "status": 200
        }
        """.utf8)

        let envelope = try DocmostJSONDecoder.make().decode(
            APIEnvelope<DocmostPageRestrictionInfo>.self,
            from: data
        )

        #expect(envelope.data.hasAnyRestriction)
        #expect(envelope.data.hasInheritedRestriction)
        #expect(envelope.data.inheritedFrom?.slugId == "parent")
        #expect(envelope.data.userAccess.canView)
        #expect(envelope.data.userAccess.canEdit == false)
    }

    @Test func decodesPagePermissionMembersResponse() throws {
        let data = Data("""
        {
          "data": {
            "items": [
              {
                "id": "user-1",
                "type": "user",
                "name": "Ada Lovelace",
                "email": "ada@example.com",
                "avatarUrl": null,
                "role": "writer",
                "createdAt": "2026-07-04T09:00:00.000Z"
              },
              {
                "id": "group-1",
                "type": "group",
                "name": "Engineering",
                "memberCount": 4,
                "isDefault": false,
                "role": "reader",
                "createdAt": "2026-07-04T09:00:00.000Z"
              }
            ],
            "meta": {
              "limit": 50,
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
            APIEnvelope<PaginatedResponse<DocmostPagePermissionMember>>.self,
            from: data
        )

        #expect(envelope.data.items.count == 2)
        #expect(envelope.data.items[0].type == .user)
        #expect(envelope.data.items[0].role == .writer)
        #expect(envelope.data.items[1].memberCount == 4)
    }
}
