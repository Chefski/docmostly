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

@MainActor
final class CacheRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func saveSpaces(_ spaces: [DocmostSpace], scope: CacheScope) throws {
        try deleteSpaces(scope: scope)
        for space in spaces {
            context.insert(CachedSpace(space: space, scope: scope))
        }
        try context.save()
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
        try deleteTreeItems(spaceId: spaceId, parentPageId: parentPageId, scope: scope)
        for page in pages {
            context.insert(CachedPageTreeItem(page: page, scope: scope))
        }
        try context.save()
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
        if let cachedPage = try loadPage(idOrSlugId: page.id, scope: scope) {
            cachedPage.update(page: page, htmlContent: htmlContent)
        } else {
            context.insert(CachedPage(page: page, htmlContent: htmlContent, scope: scope))
        }

        let links = AttachmentExtractor.extractLinks(fromHTML: htmlContent)
        try deleteAttachments(pageId: page.id, scope: scope)
        for link in links {
            context.insert(CachedAttachment(link: link, pageId: page.id, scope: scope))
        }

        try context.save()
    }

    func saveEditablePage(_ page: DocmostEditablePage, scope: CacheScope) throws {
        if let cachedPage = try loadPage(idOrSlugId: page.id, scope: scope) {
            cachedPage.update(editablePage: page)
        } else {
            context.insert(CachedPage(editablePage: page, scope: scope))
        }

        try context.save()
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

    func markOpened(_ cachedPage: CachedPage) throws {
        cachedPage.lastOpenedAt = Date.now
        try context.save()
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

    func clearAll() throws {
        try deleteAll(CachedAttachment.self)
        try deleteAll(CachedPage.self)
        try deleteAll(CachedPageTreeItem.self)
        try deleteAll(CachedSpace.self)
        try context.save()
    }

    private func deleteSpaces(scope: CacheScope) throws {
        let serverBaseURL = scope.serverBaseURL
        let userID = scope.userID
        let descriptor = FetchDescriptor<CachedSpace>(
            predicate: #Predicate { space in
                space.cacheServerBaseURL == serverBaseURL && space.cacheUserID == userID
            }
        )
        for item in try context.fetch(descriptor) {
            context.delete(item)
        }
    }

    private func deleteTreeItems(spaceId: String, parentPageId: String?, scope: CacheScope) throws {
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
        for item in try context.fetch(descriptor) {
            context.delete(item)
        }
    }

    private func deleteAttachments(pageId: String, scope: CacheScope) throws {
        let serverBaseURL = scope.serverBaseURL
        let userID = scope.userID
        let descriptor = FetchDescriptor<CachedAttachment>(
            predicate: #Predicate { attachment in
                attachment.cacheServerBaseURL == serverBaseURL &&
                    attachment.cacheUserID == userID &&
                    attachment.pageId == pageId
            }
        )
        for item in try context.fetch(descriptor) {
            context.delete(item)
        }
    }

    private func deleteAll<T: PersistentModel>(_ model: T.Type) throws {
        let descriptor = FetchDescriptor<T>()
        for item in try context.fetch(descriptor) {
            context.delete(item)
        }
    }
}
