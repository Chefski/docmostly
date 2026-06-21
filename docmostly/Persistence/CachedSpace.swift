import Foundation
import SwiftData

@Model
final class CachedSpace {
    var cacheServerBaseURL: String = ""
    var cacheUserID: String = ""
    var id: String = ""
    var name: String = ""
    var spaceDescription: String?
    var logo: String?
    var slug: String = ""
    var hostname: String?
    var memberCount: Int?
    var updatedAt: Date?
    var cachedAt: Date = Date.now

    init(space: DocmostSpace, scope: CacheScope, cachedAt: Date = Date.now) {
        cacheServerBaseURL = scope.serverBaseURL
        cacheUserID = scope.userID
        id = space.id
        name = space.name
        spaceDescription = space.description
        logo = space.logo
        slug = space.slug
        hostname = space.hostname
        memberCount = space.memberCount
        updatedAt = space.updatedAt
        self.cachedAt = cachedAt
    }

    func update(space: DocmostSpace, cachedAt: Date = Date.now) {
        name = space.name
        spaceDescription = space.description
        logo = space.logo
        slug = space.slug
        hostname = space.hostname
        memberCount = space.memberCount
        updatedAt = space.updatedAt
        self.cachedAt = cachedAt
    }

    func matches(space: DocmostSpace) -> Bool {
        name == space.name &&
            spaceDescription == space.description &&
            logo == space.logo &&
            slug == space.slug &&
            hostname == space.hostname &&
            memberCount == space.memberCount &&
            updatedAt == space.updatedAt
    }

    func asSpace() -> DocmostSpace {
        DocmostSpace(
            id: id,
            name: name,
            description: spaceDescription,
            logo: logo,
            slug: slug,
            hostname: hostname,
            creatorId: nil,
            createdAt: nil,
            updatedAt: updatedAt,
            memberCount: memberCount,
            membership: nil,
            settings: nil
        )
    }
}
