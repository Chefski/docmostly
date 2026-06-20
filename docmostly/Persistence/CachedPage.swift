import Foundation
import SwiftData

@Model
final class CachedPage {
    var id: String = ""
    var slugId: String = ""
    var title: String = ""
    var htmlContent: String = ""
    var icon: String?
    var parentPageId: String?
    var spaceId: String = ""
    var spaceSlug: String?
    var updatedAt: Date?
    var cachedAt: Date = Date.now
    var lastOpenedAt: Date = Date.now

    init(page: DocmostPage, htmlContent: String, cachedAt: Date = Date.now) {
        id = page.id
        slugId = page.slugId
        title = page.title
        self.htmlContent = htmlContent
        icon = page.icon
        parentPageId = page.parentPageId
        spaceId = page.spaceId
        spaceSlug = page.space?.slug
        updatedAt = page.updatedAt
        self.cachedAt = cachedAt
        lastOpenedAt = cachedAt
    }

    func asPage() -> DocmostPage {
        DocmostPage(
            id: id,
            slugId: slugId,
            title: title,
            content: htmlContent,
            icon: icon,
            coverPhoto: nil,
            parentPageId: parentPageId,
            creatorId: nil,
            spaceId: spaceId,
            workspaceId: nil,
            isLocked: nil,
            lastUpdatedById: nil,
            createdAt: nil,
            updatedAt: updatedAt,
            deletedAt: nil,
            position: nil,
            hasChildren: nil,
            permissions: nil,
            creator: nil,
            lastUpdatedBy: nil,
            contributors: nil,
            space: DocmostPageSpace(id: nil, name: nil, slug: spaceSlug, logo: nil)
        )
    }
}
