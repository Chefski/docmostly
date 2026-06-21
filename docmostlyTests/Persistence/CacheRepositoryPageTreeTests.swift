import Foundation
import SwiftData
import Testing
@testable import docmostly

@MainActor
struct CacheRepositoryPageTreeTests {
    private let scope = CacheScope(serverBaseURL: "https://docs.example.com", userID: "user-1")

    @Test func savingUnchangedPageTreeReusesCachedRows() throws {
        let (repository, context) = makeRepository()
        let pages = [
            page(id: "page-1", title: "Roadmap", position: "a0"),
            page(id: "page-2", title: "Planning", position: "a1")
        ]

        try repository.savePageTree(spaceId: "space-1", parentPageId: nil, pages: pages, scope: scope)
        let firstCachedRows = try cachedTreeItems(context: context)

        try repository.savePageTree(spaceId: "space-1", parentPageId: nil, pages: pages, scope: scope)
        let secondCachedRows = try cachedTreeItems(context: context)

        #expect(secondCachedRows.count == 2)
        #expect(firstCachedRows[0] === secondCachedRows[0])
        #expect(firstCachedRows[1] === secondCachedRows[1])
        #expect(firstCachedRows[0].cachedAt == secondCachedRows[0].cachedAt)
        #expect(firstCachedRows[1].cachedAt == secondCachedRows[1].cachedAt)
    }

    @Test func savingChangedPageTreeUpdatesRowsWithoutReplacingUnchangedRows() throws {
        let (repository, context) = makeRepository()
        let firstPage = page(id: "page-1", title: "Roadmap", position: "a0")
        let secondPage = page(id: "page-2", title: "Planning", position: "a1")
        try repository.savePageTree(spaceId: "space-1", parentPageId: nil, pages: [firstPage, secondPage], scope: scope)
        let originalRows = try cachedTreeItems(context: context)

        try repository.savePageTree(
            spaceId: "space-1",
            parentPageId: nil,
            pages: [
                page(id: "page-1", title: "Roadmap updated", position: "a0"),
                page(id: "page-3", title: "Launch", position: "a2")
            ],
            scope: scope
        )
        let updatedRows = try cachedTreeItems(context: context)

        #expect(updatedRows.count == 2)
        #expect(updatedRows[0] === originalRows[0])
        #expect(updatedRows[0].title == "Roadmap updated")
        #expect(updatedRows[1].id == "page-3")
        #expect(updatedRows.contains { $0.id == "page-2" } == false)
    }

    private func makeRepository() -> (CacheRepository, ModelContext) {
        let container = DocmostlyModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        return (CacheRepository(context: context), context)
    }

    private func cachedTreeItems(context: ModelContext) throws -> [CachedPageTreeItem] {
        let descriptor = FetchDescriptor<CachedPageTreeItem>(
            sortBy: [SortDescriptor(\.position)]
        )
        return try context.fetch(descriptor)
    }

    private func page(id: String, title: String, position: String) -> DocmostPage {
        DocmostPage(
            id: id,
            slugId: id,
            title: title,
            content: nil,
            icon: nil,
            coverPhoto: nil,
            parentPageId: nil,
            creatorId: nil,
            spaceId: "space-1",
            workspaceId: nil,
            isLocked: nil,
            lastUpdatedById: nil,
            createdAt: nil,
            updatedAt: nil,
            deletedAt: nil,
            position: position,
            hasChildren: false,
            permissions: nil,
            creator: nil,
            lastUpdatedBy: nil,
            contributors: nil,
            space: nil
        )
    }
}
