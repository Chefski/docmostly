import SwiftData
import Testing
@testable import DocmostlyMac

@MainActor
struct DocmostlyMacTests {
    @Test func macTargetUsesSharedOfflineCacheModels() throws {
        let container = DocmostlyModelContainer.make(isStoredInMemoryOnly: true)
        let repository = CacheRepository(context: ModelContext(container))
        let space = DocmostSpace(
            id: "space-1",
            name: "Engineering",
            description: nil,
            logo: nil,
            slug: "engineering",
            hostname: nil,
            creatorId: nil,
            createdAt: nil,
            updatedAt: nil,
            memberCount: nil,
            membership: nil,
            settings: nil
        )
        let scope = CacheScope(serverBaseURL: "https://docs.example.com", userID: "user-1")

        try repository.saveSpaces([space], scope: scope)

        #expect(try repository.loadSpaces(scope: scope).map(\.id) == ["space-1"])
    }
}
