import Foundation
import SwiftData

nonisolated enum CacheWriteOperation: Sendable {
    case saveSpaces([DocmostSpace], CacheScope)
    case savePageTree(spaceId: String, parentPageId: String?, pages: [DocmostPage], scope: CacheScope)
    case savePage(DocmostPage, htmlContent: String, scope: CacheScope)
    case saveEditablePage(DocmostEditablePage, scope: CacheScope)
    case upsertEditablePageMetadata(DocmostEditablePage, scope: CacheScope)
    case updatePageIcon(pageID: String, icon: String?, updatedAt: Date?, scope: CacheScope)
    case saveAttachmentLinks(pageId: String, links: [DocmostAttachmentLink], scope: CacheScope)
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

    func saveLocalEditableDraft(
        pageId: String,
        title: String,
        document: ProseMirrorDocument,
        scope: CacheScope
    ) throws -> DocmostEditablePage {
        let repository = CacheRepository(context: ModelContext(modelContainer))
        return try repository.saveLocalEditableDraft(
            pageId: pageId,
            title: title,
            document: document,
            scope: scope
        )
    }

    func saveCRDTStateUpdate(pageId: String, update: Data, scope: CacheScope) throws {
        try repository().saveCRDTStateUpdate(pageId: pageId, update: update, scope: scope)
    }

    private func repository() -> CacheRepository {
        CacheRepository(context: ModelContext(modelContainer))
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
        case let .upsertEditablePageMetadata(page, scope):
            try repository.upsertEditablePageMetadata(page, scope: scope)
        case let .updatePageIcon(pageID, icon, updatedAt, scope):
            try repository.updatePageIcon(pageID: pageID, icon: icon, updatedAt: updatedAt, scope: scope)
        case let .saveAttachmentLinks(pageId, links, scope):
            try repository.saveAttachmentLinks(links, pageId: pageId, scope: scope)
        case let .markOpened(idOrSlugId, scope):
            try repository.markOpened(idOrSlugId: idOrSlugId, scope: scope)
        case .clearAll:
            try repository.clearAll()
        }
    }
}
