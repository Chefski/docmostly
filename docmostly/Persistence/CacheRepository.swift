import Foundation
import SwiftData

@MainActor
final class CacheRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func saveSpaces(_ spaces: [DocmostSpace]) throws {
        try deleteAll(CachedSpace.self)
        for space in spaces {
            context.insert(CachedSpace(space: space))
        }
        try context.save()
    }

    func loadSpaces() throws -> [DocmostSpace] {
        let descriptor = FetchDescriptor<CachedSpace>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor).map { $0.asSpace() }
    }

    func savePageTree(spaceId: String, parentPageId: String?, pages: [DocmostPage]) throws {
        try deleteTreeItems(spaceId: spaceId, parentPageId: parentPageId)
        for page in pages {
            context.insert(CachedPageTreeItem(page: page))
        }
        try context.save()
    }

    func loadPageTree(spaceId: String, parentPageId: String?) throws -> [DocmostPage] {
        let descriptor = FetchDescriptor<CachedPageTreeItem>(
            predicate: #Predicate { item in
                item.spaceId == spaceId && item.parentPageId == parentPageId
            },
            sortBy: [SortDescriptor(\.position)]
        )
        return try context.fetch(descriptor).map { $0.asPage() }
    }

    func savePage(_ page: DocmostPage, htmlContent: String) throws {
        try deleteCachedPage(id: page.id)
        let cachedPage = CachedPage(page: page, htmlContent: htmlContent)
        context.insert(cachedPage)

        let links = AttachmentExtractor.extractLinks(fromHTML: htmlContent)
        try deleteAttachments(pageId: page.id)
        for link in links {
            context.insert(CachedAttachment(link: link, pageId: page.id))
        }

        try context.save()
    }

    func loadPage(idOrSlugId: String) throws -> CachedPage? {
        var descriptor = FetchDescriptor<CachedPage>(
            predicate: #Predicate { page in
                page.id == idOrSlugId || page.slugId == idOrSlugId
            }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    func loadRecentPages(limit: Int = 20) throws -> [CachedPage] {
        var descriptor = FetchDescriptor<CachedPage>(
            sortBy: [SortDescriptor(\.lastOpenedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func markOpened(_ cachedPage: CachedPage) throws {
        cachedPage.lastOpenedAt = Date.now
        try context.save()
    }

    func loadAttachmentLinks(pageId: String) throws -> [DocmostAttachmentLink] {
        let descriptor = FetchDescriptor<CachedAttachment>(
            predicate: #Predicate { attachment in
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

    private func deleteTreeItems(spaceId: String, parentPageId: String?) throws {
        let descriptor = FetchDescriptor<CachedPageTreeItem>(
            predicate: #Predicate { item in
                item.spaceId == spaceId && item.parentPageId == parentPageId
            }
        )
        for item in try context.fetch(descriptor) {
            context.delete(item)
        }
    }

    private func deleteCachedPage(id: String) throws {
        let descriptor = FetchDescriptor<CachedPage>(
            predicate: #Predicate { page in
                page.id == id
            }
        )
        for item in try context.fetch(descriptor) {
            context.delete(item)
        }
    }

    private func deleteAttachments(pageId: String) throws {
        let descriptor = FetchDescriptor<CachedAttachment>(
            predicate: #Predicate { attachment in
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
