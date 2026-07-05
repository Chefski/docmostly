import Foundation
import SwiftData
import Testing
@testable import docmostly

@MainActor
struct CacheRepositorySearchTests {
    private let scope = CacheScope(serverBaseURL: "https://docs.example.com", userID: "user-1")

    @Test func cachedSearchAppliesSpaceAuthorAndPaginationAfterFiltering() throws {
        let repository = makeRepository()

        try repository.savePage(
            page(id: "first-match", title: "Roadmap", spaceId: "space-1", creatorId: "user-1"),
            htmlContent: "<p>planning</p>",
            scope: scope
        )
        try repository.savePage(
            page(id: "second-match", title: "Roadmap", spaceId: "space-1", creatorId: "user-1"),
            htmlContent: "<p>planning</p>",
            scope: scope
        )
        for index in 0..<110 {
            try repository.savePage(
                page(id: "other-\(index)", title: "Roadmap", spaceId: "space-2", creatorId: "user-2"),
                htmlContent: "<p>planning</p>",
                scope: scope
            )
        }

        let results = try repository.searchCachedPages(
            CachedSearchRequest(
                query: "roadmap",
                spaceId: "space-1",
                creatorId: "user-1",
                limit: 2,
                offset: 0
            ),
            scope: scope
        )

        #expect(Set(results.map(\.id)) == ["first-match", "second-match"])
        #expect(results.map(\.creatorId) == ["user-1", "user-1"])
    }

    @Test func cachedSearchClampsNegativePagination() throws {
        let repository = makeRepository()
        try repository.savePage(
            page(id: "page-1", title: "Roadmap", spaceId: "space-1", creatorId: "user-1"),
            htmlContent: "<p>planning</p>",
            scope: scope
        )

        let negativeLimitResults = try repository.searchCachedPages(
            CachedSearchRequest(query: "roadmap", spaceId: nil, creatorId: nil, limit: -1, offset: -1),
            scope: scope
        )
        let negativeOffsetResults = try repository.searchCachedPages(
            CachedSearchRequest(query: "roadmap", spaceId: nil, creatorId: nil, limit: 1, offset: -1),
            scope: scope
        )

        #expect(negativeLimitResults.isEmpty)
        #expect(negativeOffsetResults.map(\.id) == ["page-1"])
    }

    private func makeRepository() -> CacheRepository {
        let container = DocmostlyModelContainer.make(isStoredInMemoryOnly: true)
        return CacheRepository(context: ModelContext(container))
    }

    private func page(
        id: String,
        title: String,
        spaceId: String,
        creatorId: String
    ) -> DocmostPage {
        DocmostPage(
            id: id,
            slugId: "\(id)-slug",
            title: title,
            content: nil,
            icon: nil,
            coverPhoto: nil,
            parentPageId: nil,
            creatorId: creatorId,
            spaceId: spaceId,
            workspaceId: nil,
            isLocked: nil,
            lastUpdatedById: nil,
            createdAt: nil,
            updatedAt: nil,
            deletedAt: nil,
            position: nil,
            hasChildren: nil,
            permissions: nil,
            creator: nil,
            lastUpdatedBy: nil,
            contributors: nil,
            space: DocmostPageSpace(id: spaceId, name: "Product", slug: "product", logo: nil)
        )
    }
}
