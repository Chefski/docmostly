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

        try repository.saveSpaces([space])

        #expect(try repository.loadSpaces().map(\.id) == ["space-1"])
    }
}
