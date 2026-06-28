import Foundation
import SwiftData

nonisolated struct CacheScope: Equatable, Hashable, Sendable {
    let serverBaseURL: String
    let userID: String

    init(serverBaseURL: URL, userID: String) {
        self.init(serverBaseURL: serverBaseURL.absoluteString, userID: userID)
    }

    init(serverBaseURL: String, userID: String) {
        self.serverBaseURL = serverBaseURL
        self.userID = userID
    }
}

nonisolated final class CacheRepository {
    private let context: ModelContext
    private var deferredSaveDepth = 0
    private var hasDeferredChanges = false

    init(context: ModelContext) {
        self.context = context
    }

    func performBatch(_ body: () throws -> Void) throws {
        deferredSaveDepth += 1
        do {
            try body()
        } catch {
            deferredSaveDepth -= 1
            if deferredSaveDepth == 0 {
                hasDeferredChanges = false
            }
            throw error
        }

        deferredSaveDepth -= 1
        if deferredSaveDepth == 0, hasDeferredChanges {
            hasDeferredChanges = false
            try context.save()
        }
    }

    func saveSpaces(_ spaces: [DocmostSpace], scope: CacheScope) throws {
        let existingSpaces = try loadCachedSpaces(scope: scope)
        var existingByID: [String: CachedSpace] = [:]
        var hasChanges = false
        let incomingIDs = Set(spaces.map(\.id))

        for space in existingSpaces {
            guard incomingIDs.contains(space.id) else {
                context.delete(space)
                hasChanges = true
                continue
            }

            if existingByID[space.id] == nil {
                existingByID[space.id] = space
            } else {
                context.delete(space)
                hasChanges = true
            }
        }

        for space in spaces {
            if let existing = existingByID.removeValue(forKey: space.id) {
                if existing.matches(space: space) == false {
                    existing.update(space: space)
                    hasChanges = true
                }
            } else {
                context.insert(CachedSpace(space: space, scope: scope))
                hasChanges = true
            }
        }

        try saveIfNeeded(hasChanges)
    }

    func loadSpaces(scope: CacheScope) throws -> [DocmostSpace] {
        let serverBaseURL = scope.serverBaseURL
        let userID = scope.userID
        let descriptor = FetchDescriptor<CachedSpace>(
            predicate: #Predicate { space in
                space.cacheServerBaseURL == serverBaseURL && space.cacheUserID == userID
            },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor).map { $0.asSpace() }
    }

    func savePageTree(spaceId: String, parentPageId: String?, pages: [DocmostPage], scope: CacheScope) throws {
        let existingItems = try loadTreeItems(spaceId: spaceId, parentPageId: parentPageId, scope: scope)
        var existingByID: [String: CachedPageTreeItem] = [:]
        let incomingIDs = Set(pages.map(\.id))
        var hasChanges = false

        for item in existingItems {
            guard incomingIDs.contains(item.id) else {
                context.delete(item)
                hasChanges = true
                continue
            }

            if existingByID[item.id] == nil {
                existingByID[item.id] = item
            } else {
                context.delete(item)
                hasChanges = true
            }
        }

        for page in pages {
            if let existing = existingByID.removeValue(forKey: page.id) {
                if existing.matches(page: page) == false {
                    existing.update(page: page)
                    hasChanges = true
                }
            } else {
                context.insert(CachedPageTreeItem(page: page, scope: scope))
                hasChanges = true
            }
        }

        try saveIfNeeded(hasChanges)
    }

    func loadPageTree(spaceId: String, parentPageId: String?, scope: CacheScope) throws -> [DocmostPage] {
        let serverBaseURL = scope.serverBaseURL
        let userID = scope.userID
        let parentID = parentPageId
        let descriptor = FetchDescriptor<CachedPageTreeItem>(
            predicate: #Predicate { item in
                item.cacheServerBaseURL == serverBaseURL &&
                    item.cacheUserID == userID &&
                    item.spaceId == spaceId &&
                    item.parentPageId == parentID
            },
            sortBy: [SortDescriptor(\.position)]
        )
        return try context.fetch(descriptor).map { $0.asPage() }
    }

    func savePage(_ page: DocmostPage, htmlContent: String, scope: CacheScope) throws {
        var hasChanges = false
        if let cachedPage = try loadPage(idOrSlugId: page.id, scope: scope) {
            if cachedPage.matches(page: page, htmlContent: htmlContent) == false {
                cachedPage.update(page: page, htmlContent: htmlContent)
                hasChanges = true
            }
        } else {
            context.insert(CachedPage(page: page, htmlContent: htmlContent, scope: scope))
            hasChanges = true
        }

        let links = AttachmentExtractor.extractLinks(fromHTML: htmlContent)
        if try syncAttachments(links, pageId: page.id, scope: scope) {
            hasChanges = true
        }

        try saveIfNeeded(hasChanges)
    }

    func saveEditablePage(_ page: DocmostEditablePage, scope: CacheScope) throws {
        var hasChanges = false
        if let cachedPage = try loadPage(idOrSlugId: page.id, scope: scope) {
            if cachedPage.matches(editablePage: page) == false {
                cachedPage.update(editablePage: page)
                hasChanges = true
            }
        } else {
            context.insert(CachedPage(editablePage: page, scope: scope))
            hasChanges = true
        }

        try saveIfNeeded(hasChanges)
    }

    func loadPage(idOrSlugId: String, scope: CacheScope) throws -> CachedPage? {
        let serverBaseURL = scope.serverBaseURL
        let userID = scope.userID
        var descriptor = FetchDescriptor<CachedPage>(
            predicate: #Predicate { page in
                page.cacheServerBaseURL == serverBaseURL &&
                    page.cacheUserID == userID &&
                    (page.id == idOrSlugId || page.slugId == idOrSlugId)
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func loadEditablePage(idOrSlugId: String, scope: CacheScope) throws -> DocmostEditablePage? {
        try loadPage(idOrSlugId: idOrSlugId, scope: scope)?.asEditablePage()
    }

    func saveLocalEditableDraft(
        pageId: String,
        title: String,
        document: ProseMirrorDocument,
        scope: CacheScope
    ) throws -> DocmostEditablePage {
        guard let cachedPage = try loadPage(idOrSlugId: pageId, scope: scope) else {
            throw APIError.connectionFailed("This page is not cached for offline editing.")
        }

        cachedPage.updateLocalDraft(title: title, document: document)
        try saveIfNeeded(true)
        guard let page = try cachedPage.asEditablePage() else {
            throw APIError.connectionFailed("This page is not cached for offline editing.")
        }
        return page
    }

    func loadPageSnapshot(idOrSlugId: String, scope: CacheScope) throws -> CachedPageSnapshot? {
        try loadPage(idOrSlugId: idOrSlugId, scope: scope)?.snapshot()
    }

    func loadRecentPages(limit: Int = 20, scope: CacheScope) throws -> [CachedPage] {
        let serverBaseURL = scope.serverBaseURL
        let userID = scope.userID
        var descriptor = FetchDescriptor<CachedPage>(
            predicate: #Predicate { page in
                page.cacheServerBaseURL == serverBaseURL && page.cacheUserID == userID
            },
            sortBy: [SortDescriptor(\.lastOpenedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func loadRecentPageValues(limit: Int = 20, scope: CacheScope) throws -> [DocmostPage] {
        try loadRecentPages(limit: limit, scope: scope).map { $0.asPage() }
    }

    func markOpened(_ cachedPage: CachedPage) throws {
        cachedPage.lastOpenedAt = Date.now
        try saveIfNeeded(true)
    }

    func markOpened(idOrSlugId: String, scope: CacheScope) throws {
        guard let cachedPage = try loadPage(idOrSlugId: idOrSlugId, scope: scope) else { return }
        try markOpened(cachedPage)
    }

    func loadAttachmentLinks(pageId: String, scope: CacheScope) throws -> [DocmostAttachmentLink] {
        let serverBaseURL = scope.serverBaseURL
        let userID = scope.userID
        let descriptor = FetchDescriptor<CachedAttachment>(
            predicate: #Predicate { attachment in
                attachment.cacheServerBaseURL == serverBaseURL &&
                    attachment.cacheUserID == userID &&
                    attachment.pageId == pageId
            },
            sortBy: [SortDescriptor(\.fileName)]
        )
        return try context.fetch(descriptor).map { $0.asLink() }
    }

    func searchCachedPages(query: String, limit: Int = 100, scope: CacheScope) throws -> [DocmostSearchResult] {
        let pages = try loadRecentPages(limit: limit, scope: scope)
        return pages
            .filter { page in
                page.title.localizedStandardContains(query) || page.htmlContent.localizedStandardContains(query)
            }
            .map { page in
                DocmostSearchResult(
                    id: page.id,
                    title: page.title,
                    icon: page.icon,
                    parentPageId: page.parentPageId,
                    slugId: page.slugId,
                    creatorId: nil,
                    createdAt: nil,
                    updatedAt: page.updatedAt,
                    rank: nil,
                    highlight: "Cached page",
                    space: SearchResultSpace(
                        id: page.spaceId,
                        name: page.spaceSlug ?? "Cached",
                        slug: page.spaceSlug,
                        icon: nil
                    )
                )
            }
    }

    func clearAll() throws {
        try deleteAll(CachedAttachment.self)
        try deleteAll(CachedPage.self)
        try deleteAll(CachedPageTreeItem.self)
        try deleteAll(CachedSpace.self)
        try saveIfNeeded(true)
    }

    private func saveIfNeeded(_ hasChanges: Bool) throws {
        guard hasChanges else { return }

        if deferredSaveDepth > 0 {
            hasDeferredChanges = true
        } else {
            try context.save()
        }
    }

    private func loadCachedSpaces(scope: CacheScope) throws -> [CachedSpace] {
        let serverBaseURL = scope.serverBaseURL
        let userID = scope.userID
        let descriptor = FetchDescriptor<CachedSpace>(
            predicate: #Predicate { space in
                space.cacheServerBaseURL == serverBaseURL && space.cacheUserID == userID
            }
        )
        return try context.fetch(descriptor)
    }

    private func loadTreeItems(
        spaceId: String,
        parentPageId: String?,
        scope: CacheScope
    ) throws -> [CachedPageTreeItem] {
        let serverBaseURL = scope.serverBaseURL
        let userID = scope.userID
        let parentID = parentPageId
        let descriptor = FetchDescriptor<CachedPageTreeItem>(
            predicate: #Predicate { item in
                item.cacheServerBaseURL == serverBaseURL &&
                    item.cacheUserID == userID &&
                    item.spaceId == spaceId &&
                    item.parentPageId == parentID
            }
        )
        return try context.fetch(descriptor)
    }

    private func loadAttachments(pageId: String, scope: CacheScope) throws -> [CachedAttachment] {
        let serverBaseURL = scope.serverBaseURL
        let userID = scope.userID
        let descriptor = FetchDescriptor<CachedAttachment>(
            predicate: #Predicate { attachment in
                attachment.cacheServerBaseURL == serverBaseURL &&
                    attachment.cacheUserID == userID &&
                    attachment.pageId == pageId
            }
        )
        return try context.fetch(descriptor)
    }

    private func syncAttachments(
        _ links: [DocmostAttachmentLink],
        pageId: String,
        scope: CacheScope
    ) throws -> Bool {
        let existingAttachments = try loadAttachments(pageId: pageId, scope: scope)
        var existingByID: [String: CachedAttachment] = [:]
        let incomingIDs = Set(links.map(\.id))
        var hasChanges = false

        for attachment in existingAttachments {
            guard incomingIDs.contains(attachment.id) else {
                context.delete(attachment)
                hasChanges = true
                continue
            }

            if existingByID[attachment.id] == nil {
                existingByID[attachment.id] = attachment
            } else {
                context.delete(attachment)
                hasChanges = true
            }
        }

        for link in links {
            if let existing = existingByID.removeValue(forKey: link.id) {
                if existing.matches(link: link) == false {
                    existing.update(link: link)
                    hasChanges = true
                }
            } else {
                context.insert(CachedAttachment(link: link, pageId: pageId, scope: scope))
                hasChanges = true
            }
        }

        return hasChanges
    }

    private func deleteAll<T: PersistentModel>(_ model: T.Type) throws {
        let descriptor = FetchDescriptor<T>()
        for item in try context.fetch(descriptor) {
            context.delete(item)
        }
    }
}
