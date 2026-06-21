import SwiftData

nonisolated enum CacheWriteOperation: Sendable {
    case saveSpaces([DocmostSpace], CacheScope)
    case savePageTree(spaceId: String, parentPageId: String?, pages: [DocmostPage], scope: CacheScope)
    case savePage(DocmostPage, htmlContent: String, scope: CacheScope)
    case saveEditablePage(DocmostEditablePage, scope: CacheScope)
    case markOpened(idOrSlugId: String, scope: CacheScope)
    case clearAll
}

actor CacheWriteRepository {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func perform(_ operations: [CacheWriteOperation]) throws {
        let modelContext = ModelContext(modelContainer)
        let repository = CacheRepository(context: modelContext)

        try repository.performBatch {
            for operation in operations {
                try operation.perform(using: repository)
            }
        }
    }
}

nonisolated extension CacheWriteOperation {
    func perform(using repository: CacheRepository) throws {
        switch self {
        case let .saveSpaces(spaces, scope):
            try repository.saveSpaces(spaces, scope: scope)
        case let .savePageTree(spaceId, parentPageId, pages, scope):
            try repository.savePageTree(
                spaceId: spaceId,
                parentPageId: parentPageId,
                pages: pages,
                scope: scope
            )
        case let .savePage(page, htmlContent, scope):
            try repository.savePage(page, htmlContent: htmlContent, scope: scope)
        case let .saveEditablePage(page, scope):
            try repository.saveEditablePage(page, scope: scope)
        case let .markOpened(idOrSlugId, scope):
            try repository.markOpened(idOrSlugId: idOrSlugId, scope: scope)
        case .clearAll:
            try repository.clearAll()
        }
    }
}
