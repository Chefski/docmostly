import Foundation
import SwiftData
import Testing
@testable import docmostly

@MainActor
struct CacheRepositorySpacesTests {
    private let scope = CacheScope(serverBaseURL: "https://docs.example.com", userID: "user-1")

    @Test func savingUnchangedSpacesReusesCachedRows() throws {
        let (repository, context) = makeRepository()
        let spaces = [
            space(id: "space-1", name: "Product"),
            space(id: "space-2", name: "Engineering")
        ]

        try repository.saveSpaces(spaces, scope: scope)
        let firstCachedRows = try cachedSpaces(context: context)

        try repository.saveSpaces(spaces, scope: scope)
        let secondCachedRows = try cachedSpaces(context: context)

        #expect(secondCachedRows.count == 2)
        #expect(firstCachedRows[0] === secondCachedRows[0])
        #expect(firstCachedRows[1] === secondCachedRows[1])
        #expect(firstCachedRows[0].cachedAt == secondCachedRows[0].cachedAt)
        #expect(firstCachedRows[1].cachedAt == secondCachedRows[1].cachedAt)
    }

    @Test func savingChangedSpacesUpdatesRowsWithoutReplacingUnchangedRows() throws {
        let (repository, context) = makeRepository()
        try repository.saveSpaces([
            space(id: "space-1", name: "Product"),
            space(id: "space-2", name: "Engineering")
        ], scope: scope)
        let originalRows = try cachedSpaces(context: context)

        try repository.saveSpaces([
            space(id: "space-1", name: "Product ops"),
            space(id: "space-3", name: "Support")
        ], scope: scope)
        let updatedRows = try cachedSpaces(context: context)

        #expect(updatedRows.count == 2)
        #expect(updatedRows[0] === originalRows[0])
        #expect(updatedRows[0].name == "Product ops")
        #expect(updatedRows[1].id == "space-3")
        #expect(updatedRows.contains { $0.id == "space-2" } == false)
    }

    @Test func batchPersistsMultipleSpaceChanges() throws {
        let (repository, context) = makeRepository()

        try repository.performBatch {
            try repository.saveSpaces([
                space(id: "space-1", name: "Product"),
                space(id: "space-2", name: "Engineering")
            ], scope: scope)
            try repository.saveSpaces([
                space(id: "space-1", name: "Product ops"),
                space(id: "space-3", name: "Support")
            ], scope: scope)
        }

        let cachedRows = try cachedSpaces(context: context)
        #expect(cachedRows.count == 2)
        #expect(cachedRows[0].id == "space-1")
        #expect(cachedRows[0].name == "Product ops")
        #expect(cachedRows[1].id == "space-3")
    }

    private func makeRepository() -> (CacheRepository, ModelContext) {
        let container = DocmostlyModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        return (CacheRepository(context: context), context)
    }

    private func cachedSpaces(context: ModelContext) throws -> [CachedSpace] {
        let descriptor = FetchDescriptor<CachedSpace>(
            sortBy: [SortDescriptor(\.id)]
        )
        return try context.fetch(descriptor)
    }

    private func space(id: String, name: String) -> DocmostSpace {
        DocmostSpace(
            id: id,
            name: name,
            description: "Workspace for \(name)",
            logo: nil,
            slug: name.lowercased(),
            hostname: nil,
            creatorId: nil,
            createdAt: nil,
            updatedAt: nil,
            memberCount: nil,
            membership: nil,
            settings: nil
        )
    }
}
