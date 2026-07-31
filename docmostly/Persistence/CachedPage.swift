import Foundation
import SwiftData

@Model
final class CachedPage {
    var cacheServerBaseURL: String = ""
    var cacheUserID: String = ""
    var id: String = ""
    var slugId: String = ""
    var title: String = ""
    var htmlContent: String = ""
    var proseMirrorJSONData: Data?
    var icon: String?
    var parentPageId: String?
    var creatorId: String?
    var spaceId: String = ""
    var spaceSlug: String?
    var updatedAt: Date?
    var canEdit: Bool?
    var hasRestriction: Bool?
    var cachedAt: Date = Date.now
    var lastOpenedAt: Date = Date.now

    init(
        page: DocmostPage,
        htmlContent: String,
        scope: CacheScope,
        proseMirrorDocument: ProseMirrorDocument? = nil,
        cachedAt: Date = Date.now
    ) {
        cacheServerBaseURL = scope.serverBaseURL
        cacheUserID = scope.userID
        id = page.id
        slugId = page.slugId
        title = page.title
        self.htmlContent = htmlContent
        proseMirrorJSONData = proseMirrorDocument.flatMap { try? JSONEncoder().encode($0) }
        icon = page.icon
        parentPageId = page.parentPageId
        creatorId = page.creatorId
        spaceId = page.spaceId
        spaceSlug = page.space?.slug
        updatedAt = page.updatedAt
        if let permissions = page.permissions {
            canEdit = permissions.canEdit
            hasRestriction = permissions.hasRestriction
        }
        self.cachedAt = cachedAt
        lastOpenedAt = cachedAt
    }

    init(editablePage: DocmostEditablePage, scope: CacheScope, cachedAt: Date = Date.now) {
        cacheServerBaseURL = scope.serverBaseURL
        cacheUserID = scope.userID
        id = editablePage.id
        slugId = editablePage.slugId
        title = editablePage.title
        proseMirrorJSONData = try? JSONEncoder().encode(editablePage.content ?? ProseMirrorDocument())
        icon = editablePage.icon
        spaceId = editablePage.spaceId
        updatedAt = editablePage.updatedAt
        canEdit = editablePage.permissions?.canEdit
        hasRestriction = editablePage.permissions?.hasRestriction
        self.cachedAt = cachedAt
        lastOpenedAt = cachedAt
    }

    init(editablePageMetadata: DocmostEditablePage, scope: CacheScope, cachedAt: Date = Date.now) {
        cacheServerBaseURL = scope.serverBaseURL
        cacheUserID = scope.userID
        id = editablePageMetadata.id
        slugId = editablePageMetadata.slugId
        title = editablePageMetadata.title
        proseMirrorJSONData = try? JSONEncoder().encode(ProseMirrorDocument())
        icon = editablePageMetadata.icon
        spaceId = editablePageMetadata.spaceId
        updatedAt = editablePageMetadata.updatedAt
        canEdit = editablePageMetadata.permissions?.canEdit
        hasRestriction = editablePageMetadata.permissions?.hasRestriction
        self.cachedAt = cachedAt
        lastOpenedAt = cachedAt
    }

    func update(page: DocmostPage, htmlContent: String) {
        id = page.id
        slugId = page.slugId
        title = page.title
        self.htmlContent = htmlContent
        icon = page.icon
        parentPageId = page.parentPageId
        creatorId = page.creatorId
        spaceId = page.spaceId
        spaceSlug = page.space?.slug ?? spaceSlug
        updatedAt = page.updatedAt
        if let permissions = page.permissions {
            canEdit = permissions.canEdit
            hasRestriction = permissions.hasRestriction
        }
        cachedAt = Date.now
    }

    func matches(page: DocmostPage, htmlContent: String) -> Bool {
        let permissionsMatch = if let permissions = page.permissions {
            canEdit == Optional(permissions.canEdit) && hasRestriction == Optional(permissions.hasRestriction)
        } else {
            true
        }

        return id == page.id &&
            slugId == page.slugId &&
            title == page.title &&
            self.htmlContent == htmlContent &&
            icon == page.icon &&
            parentPageId == page.parentPageId &&
            creatorId == page.creatorId &&
            spaceId == page.spaceId &&
            (page.space?.slug == nil || spaceSlug == page.space?.slug) &&
            updatedAt == page.updatedAt &&
            permissionsMatch
    }

    func update(editablePage: DocmostEditablePage) {
        id = editablePage.id
        slugId = editablePage.slugId
        title = editablePage.title
        proseMirrorJSONData = try? JSONEncoder().encode(editablePage.content ?? ProseMirrorDocument())
        icon = editablePage.icon
        spaceId = editablePage.spaceId
        updatedAt = editablePage.updatedAt
        canEdit = editablePage.permissions?.canEdit
        hasRestriction = editablePage.permissions?.hasRestriction
        cachedAt = Date.now
    }

    func updateMetadata(editablePage: DocmostEditablePage) {
        id = editablePage.id
        slugId = editablePage.slugId
        title = editablePage.title
        icon = editablePage.icon
        spaceId = editablePage.spaceId
        if let updatedAt = editablePage.updatedAt {
            self.updatedAt = updatedAt
        }
        if let permissions = editablePage.permissions {
            canEdit = permissions.canEdit
            hasRestriction = permissions.hasRestriction
        }
        cachedAt = .now
    }

    func updateLocalDraft(title: String, document: ProseMirrorDocument) throws {
        let data = try JSONEncoder().encode(document)
        self.title = title
        proseMirrorJSONData = data
        cachedAt = Date.now
    }

    func matches(editablePage: DocmostEditablePage) -> Bool {
        id == editablePage.id &&
            slugId == editablePage.slugId &&
            title == editablePage.title &&
            cachedProseMirrorDocument() == (editablePage.content ?? ProseMirrorDocument()) &&
            icon == editablePage.icon &&
            spaceId == editablePage.spaceId &&
            updatedAt == editablePage.updatedAt &&
            permissions == editablePage.permissions
    }

    func snapshot() -> CachedPageSnapshot {
        CachedPageSnapshot(page: asPage(), htmlContent: htmlContent)
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
            creatorId: creatorId,
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

    func asEditablePage() throws -> DocmostEditablePage? {
        guard let proseMirrorJSONData else { return nil }

        return DocmostEditablePage(
            id: id,
            slugId: slugId,
            title: title,
            content: try ProseMirrorDocument.decode(from: proseMirrorJSONData),
            icon: icon,
            spaceId: spaceId,
            createdAt: nil,
            updatedAt: updatedAt,
            permissions: permissions,
            creator: nil,
            lastUpdatedBy: nil
        )
    }

    private var permissions: DocmostPagePermissions? {
        guard let canEdit, let hasRestriction else { return nil }
        return DocmostPagePermissions(canEdit: canEdit, hasRestriction: hasRestriction)
    }

    private func cachedProseMirrorDocument() -> ProseMirrorDocument? {
        guard let proseMirrorJSONData else { return nil }
        return try? ProseMirrorDocument.decode(from: proseMirrorJSONData)
    }
}

nonisolated struct CachedPageSnapshot: Sendable {
    let page: DocmostPage
    let htmlContent: String
}
