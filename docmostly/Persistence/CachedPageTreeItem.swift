import Foundation
import SwiftData

@Model
final class CachedPageTreeItem {
    var cacheServerBaseURL: String = ""
    var cacheUserID: String = ""
    var id: String = ""
    var slugId: String = ""
    var title: String = ""
    var icon: String?
    var parentPageId: String?
    var spaceId: String = ""
    var position: String?
    var hasChildren: Bool = false
    var cachedAt: Date = Date.now

    init(page: DocmostPage, scope: CacheScope, cachedAt: Date = Date.now) {
        cacheServerBaseURL = scope.serverBaseURL
        cacheUserID = scope.userID
        id = page.id
        slugId = page.slugId
        title = page.title
        icon = page.icon
        parentPageId = page.parentPageId
        spaceId = page.spaceId
        position = page.position
        hasChildren = page.hasChildren ?? false
        self.cachedAt = cachedAt
    }

    func asPage() -> DocmostPage {
        DocmostPage(
            id: id,
            slugId: slugId,
            title: title,
            content: nil,
            icon: icon,
            coverPhoto: nil,
            parentPageId: parentPageId,
            creatorId: nil,
            spaceId: spaceId,
            workspaceId: nil,
            isLocked: nil,
            lastUpdatedById: nil,
            createdAt: nil,
            updatedAt: nil,
            deletedAt: nil,
            position: position,
            hasChildren: hasChildren,
            permissions: nil,
            creator: nil,
            lastUpdatedBy: nil,
            contributors: nil,
            space: nil
        )
    }
}
