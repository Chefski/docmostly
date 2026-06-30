import Foundation
import Testing
@testable import docmostly

struct NativeEditorMentionSearchTests {
    @Test func buildsPageMentionFromSearchResult() {
        let mention = NativeEditorMention(pageSearchResult: searchResult())

        #expect(mention.label == "Roadmap")
        #expect(mention.entityType == "page")
        #expect(mention.entityID == "page-1")
        #expect(mention.slugID == "roadmap-abc123")
        #expect(mention.creatorID == "user-1")
        #expect(mention.displayText == "Roadmap")
    }

    @Test func buildsUserMentionFromSuggestionResult() {
        let user = DocmostMentionUserSuggestion(
            id: "user-1",
            name: "Taylor",
            email: "taylor@example.com",
            avatarUrl: "https://docs.example.com/avatar.png"
        )
        let mention = NativeEditorMention(userSuggestion: user, creatorID: "current-user")

        #expect(mention.label == "Taylor")
        #expect(mention.entityType == "user")
        #expect(mention.entityID == "user-1")
        #expect(mention.creatorID == "current-user")
        #expect(mention.displayText == "@Taylor")
    }

    @Test func decodesDocmostMentionSuggestionResponse() throws {
        let data = Data("""
        {
          "users": [
            {
              "id": "user-1",
              "name": "Taylor",
              "email": "taylor@example.com",
              "avatarUrl": "https://docs.example.com/avatar.png"
            }
          ],
          "pages": [
            {
              "id": "page-1",
              "slugId": "roadmap-abc123",
              "title": "Roadmap",
              "icon": "R",
              "spaceId": "space-1",
              "space": {
                "id": "space-1",
                "name": "Product",
                "slug": "product",
                "icon": null
              }
            }
          ]
        }
        """.utf8)

        let response = try DocmostJSONDecoder.make().decode(DocmostMentionSuggestionResponse.self, from: data)

        #expect(response.users.first?.name == "Taylor")
        #expect(response.pages.first?.title == "Roadmap")
        #expect(response.pages.first?.space?.name == "Product")
    }

    private func searchResult() -> DocmostSearchResult {
        DocmostSearchResult(
            id: "page-1",
            title: "Roadmap",
            icon: nil,
            parentPageId: nil,
            slugId: "roadmap-abc123",
            creatorId: "user-1",
            createdAt: nil,
            updatedAt: nil,
            rank: nil,
            highlight: nil,
            space: SearchResultSpace(id: "space-1", name: "Product", slug: "product", icon: nil)
        )
    }
}
