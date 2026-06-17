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
