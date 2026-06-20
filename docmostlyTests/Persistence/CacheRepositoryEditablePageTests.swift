import SwiftData
import Testing
@testable import docmostly

@MainActor
struct CacheRepositoryEditablePageTests {
    @Test func savingEditablePagePreservesNativeDocumentForOfflineReading() throws {
        let repository = makeRepository()
        let document = ProseMirrorDocument(content: [
            ProseMirrorNode(
                type: "paragraph",
                content: [
                    ProseMirrorNode(type: "text", text: "Offline body")
                ]
            )
        ])

        try repository.saveEditablePage(editablePage(content: document))

        let loadedPage = try repository.loadEditablePage(idOrSlugId: "page-1")
        let cached = try #require(loadedPage)
        #expect(cached.id == "page-1")
        #expect(cached.slugId == "roadmap")
        #expect(cached.title == "Roadmap")
        #expect(cached.content == document)
    }

    @Test func cachedEditablePagesAreReadOnly() throws {
        let repository = makeRepository()

        try repository.saveEditablePage(editablePage(content: ProseMirrorDocument()))

        let loadedPage = try repository.loadEditablePage(idOrSlugId: "roadmap")
        let cached = try #require(loadedPage)
        #expect(cached.permissions?.canEdit == false)
    }

    @Test func savingHTMLPageDoesNotDiscardCachedNativeDocument() throws {
        let repository = makeRepository()
        let document = ProseMirrorDocument(content: [
            ProseMirrorNode(
                type: "heading",
                attrs: ["level": .int(2)],
                content: [
                    ProseMirrorNode(type: "text", text: "Plan")
                ]
            )
        ])

        try repository.saveEditablePage(editablePage(content: document))
        try repository.savePage(htmlPage(title: "Roadmap updated"), htmlContent: "<p>Updated</p>")

        let loadedPage = try repository.loadEditablePage(idOrSlugId: "page-1")
        let cached = try #require(loadedPage)
        #expect(cached.title == "Roadmap updated")
        #expect(cached.content == document)
        #expect(cached.permissions?.canEdit == false)
    }

    private func makeRepository() -> CacheRepository {
        let container = DocmostlyModelContainer.make(isStoredInMemoryOnly: true)
        return CacheRepository(context: ModelContext(container))
    }

    private func editablePage(content: ProseMirrorDocument?) -> DocmostEditablePage {
        DocmostEditablePage(
            id: "page-1",
            slugId: "roadmap",
            title: "Roadmap",
            content: content,
            icon: nil,
            spaceId: "space-1",
            updatedAt: nil,
            permissions: DocmostPagePermissions(canEdit: true, hasRestriction: false),
            lastUpdatedBy: nil
        )
    }

    private func htmlPage(title: String) -> DocmostPage {
        DocmostPage(
            id: "page-1",
            slugId: "roadmap",
            title: title,
            content: nil,
            icon: nil,
            coverPhoto: nil,
            parentPageId: nil,
            creatorId: nil,
            spaceId: "space-1",
            workspaceId: nil,
            isLocked: nil,
            lastUpdatedById: nil,
            createdAt: nil,
            updatedAt: nil,
            deletedAt: nil,
            position: nil,
            hasChildren: nil,
            permissions: nil,
            creator: nil,
            lastUpdatedBy: nil,
            contributors: nil,
            space: DocmostPageSpace(id: "space-1", name: "Product", slug: "product", logo: nil)
        )
    }
}
