import SwiftData

actor CacheReadRepository {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func loadSpaces(scope: CacheScope) throws -> [DocmostSpace] {
        try repository().loadSpaces(scope: scope)
    }

    func loadPageTree(spaceId: String, parentPageId: String?, scope: CacheScope) throws -> [DocmostPage] {
        try repository().loadPageTree(spaceId: spaceId, parentPageId: parentPageId, scope: scope)
    }

    func loadPageSnapshot(idOrSlugId: String, scope: CacheScope) throws -> CachedPageSnapshot? {
        try repository().loadPageSnapshot(idOrSlugId: idOrSlugId, scope: scope)
    }

    func loadEditablePage(idOrSlugId: String, scope: CacheScope) throws -> DocmostEditablePage? {
        try repository().loadEditablePage(idOrSlugId: idOrSlugId, scope: scope)
    }

    func loadAttachmentLinks(pageId: String, scope: CacheScope) throws -> [DocmostAttachmentLink] {
        try repository().loadAttachmentLinks(pageId: pageId, scope: scope)
    }

    func loadRecentPageValues(limit: Int, scope: CacheScope) throws -> [DocmostPage] {
        try repository().loadRecentPageValues(limit: limit, scope: scope)
    }

    func searchCachedPages(query: String, limit: Int, scope: CacheScope) throws -> [DocmostSearchResult] {
        try repository().searchCachedPages(query: query, limit: limit, scope: scope)
    }

    private func repository() -> CacheRepository {
        CacheRepository(context: ModelContext(modelContainer))
    }
}
