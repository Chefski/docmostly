import Foundation
import SwiftData
import Testing
@testable import docmostly

@MainActor
struct CacheRepositoryEditablePageTests {
    private let scope = CacheScope(serverBaseURL: "https://docs.example.com", userID: "user-1")

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

        try repository.saveEditablePage(editablePage(content: document), scope: scope)

        let loadedPage = try repository.loadEditablePage(idOrSlugId: "page-1", scope: scope)
        let cached = try #require(loadedPage)
        #expect(cached.id == "page-1")
        #expect(cached.slugId == "roadmap")
        #expect(cached.title == "Roadmap")
        #expect(cached.content == document)
    }

    @Test func cachedEditablePagesPreserveEditPermissionsForOfflineEditing() throws {
        let repository = makeRepository()

        try repository.saveEditablePage(editablePage(content: ProseMirrorDocument()), scope: scope)

        let loadedPage = try repository.loadEditablePage(idOrSlugId: "roadmap", scope: scope)
        let cached = try #require(loadedPage)
        #expect(cached.permissions?.canEdit == true)
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

        try repository.saveEditablePage(editablePage(content: document), scope: scope)
        try repository.savePage(htmlPage(title: "Roadmap updated"), htmlContent: "<p>Updated</p>", scope: scope)

        let loadedPage = try repository.loadEditablePage(idOrSlugId: "page-1", scope: scope)
        let cached = try #require(loadedPage)
        #expect(cached.title == "Roadmap updated")
        #expect(cached.content == document)
        #expect(cached.permissions?.canEdit == true)
    }

    @Test func savingLocalEditableDraftPreservesCachedPageIdentityAndPermissions() throws {
        let repository = makeRepository()
        let draft = ProseMirrorDocument(content: [
            ProseMirrorNode(type: "paragraph", content: [
                ProseMirrorNode(type: "text", text: "Queued body")
            ])
        ])

        try repository.saveEditablePage(editablePage(content: ProseMirrorDocument()), scope: scope)
        let updatedPage = try repository.saveLocalEditableDraft(
            pageId: "page-1",
            title: "Queued title",
            document: draft,
            scope: scope
        )

        #expect(updatedPage.id == "page-1")
        #expect(updatedPage.slugId == "roadmap")
        #expect(updatedPage.spaceId == "space-1")
        #expect(updatedPage.title == "Queued title")
        #expect(updatedPage.content == draft)
        #expect(updatedPage.permissions?.canEdit == true)
    }

    @Test func savingEditablePageWithMissingPermissionsKeepsPermissionsUnknown() throws {
        let repository = makeRepository()

        try repository.saveEditablePage(
            editablePage(content: ProseMirrorDocument(), permissions: nil),
            scope: scope
        )

        let loadedPage = try repository.loadEditablePage(idOrSlugId: "page-1", scope: scope)
        let cached = try #require(loadedPage)
        #expect(cached.permissions == nil)
    }

    @Test func savingLocalEditableDraftPreservesRemoteUpdatedAtBaseline() throws {
        let repository = makeRepository()
        let remoteUpdatedAt = try Date("2026-06-28T08:00:00Z", strategy: .iso8601)

        try repository.saveEditablePage(
            editablePage(
                content: ProseMirrorDocument(),
                updatedAt: remoteUpdatedAt
            ),
            scope: scope
        )
        let updatedPage = try repository.saveLocalEditableDraft(
            pageId: "page-1",
            title: "Queued title",
            document: ProseMirrorDocument(content: [
                ProseMirrorNode(type: "paragraph", text: "Queued body")
            ]),
            scope: scope
        )

        #expect(updatedPage.updatedAt == remoteUpdatedAt)
    }

    @Test func savingUnchangedHTMLPageReusesCachedPageAndAttachmentRows() throws {
        let (repository, context) = makeRepositoryAndContext()
        let page = htmlPage(title: "Roadmap")
        let html = """
        <p>Updated plan <a href="/api/files/file-1/diagram.svg">diagram</a></p>
        """

        try repository.savePage(page, htmlContent: html, scope: scope)
        let firstPages = try cachedPages(context: context)
        let firstAttachments = try cachedAttachments(context: context)

        try repository.savePage(page, htmlContent: html, scope: scope)
        let secondPages = try cachedPages(context: context)
        let secondAttachments = try cachedAttachments(context: context)

        #expect(secondPages.count == 1)
        #expect(secondAttachments.count == 1)
        #expect(firstPages[0] === secondPages[0])
        #expect(firstAttachments[0] === secondAttachments[0])
        #expect(firstPages[0].cachedAt == secondPages[0].cachedAt)
        #expect(firstAttachments[0].cachedAt == secondAttachments[0].cachedAt)
    }

    @Test func savingChangedAttachmentUpdatesExistingRowWithoutReplacingPage() throws {
        let (repository, context) = makeRepositoryAndContext()
        let page = htmlPage(title: "Roadmap")

        try repository.savePage(
            page,
            htmlContent: #"<p><a href="/api/files/file-1/diagram.svg">diagram</a></p>"#,
            scope: scope
        )
        let originalPageRow = try #require(cachedPages(context: context).first)
        let originalAttachmentRow = try #require(cachedAttachments(context: context).first)

        try repository.savePage(
            page,
            htmlContent: #"<p><a href="/api/files/file-1/updated-diagram.svg">diagram</a></p>"#,
            scope: scope
        )
        let updatedPageRow = try #require(cachedPages(context: context).first)
        let updatedAttachmentRow = try #require(cachedAttachments(context: context).first)

        #expect(updatedPageRow === originalPageRow)
        #expect(updatedAttachmentRow === originalAttachmentRow)
        #expect(updatedAttachmentRow.fileName == "updated-diagram.svg")
    }

    @Test func cachedEditablePagesAreScopedByServerAndUser() throws {
        let repository = makeRepository()
        let otherUserScope = CacheScope(serverBaseURL: "https://docs.example.com", userID: "user-2")
        let otherServerScope = CacheScope(serverBaseURL: "https://other.example.com", userID: "user-1")

        try repository.saveEditablePage(editablePage(content: ProseMirrorDocument()), scope: scope)

        #expect(try repository.loadEditablePage(idOrSlugId: "page-1", scope: scope) != nil)
        #expect(try repository.loadEditablePage(idOrSlugId: "page-1", scope: otherUserScope) == nil)
        #expect(try repository.loadEditablePage(idOrSlugId: "page-1", scope: otherServerScope) == nil)
    }

    private func makeRepository() -> CacheRepository {
        makeRepositoryAndContext().0
    }

    private func makeRepositoryAndContext() -> (CacheRepository, ModelContext) {
        let container = DocmostlyModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        return (CacheRepository(context: context), context)
    }

    private func cachedPages(context: ModelContext) throws -> [CachedPage] {
        let descriptor = FetchDescriptor<CachedPage>(
            sortBy: [SortDescriptor(\.id)]
        )
        return try context.fetch(descriptor)
    }

    private func cachedAttachments(context: ModelContext) throws -> [CachedAttachment] {
        let descriptor = FetchDescriptor<CachedAttachment>(
            sortBy: [SortDescriptor(\.id)]
        )
        return try context.fetch(descriptor)
    }

    private func editablePage(
        content: ProseMirrorDocument?,
        updatedAt: Date? = nil,
        permissions: DocmostPagePermissions? = DocmostPagePermissions(canEdit: true, hasRestriction: false)
    ) -> DocmostEditablePage {
        DocmostEditablePage(
            id: "page-1",
            slugId: "roadmap",
            title: "Roadmap",
            content: content,
            icon: nil,
            spaceId: "space-1",
            updatedAt: updatedAt,
            permissions: permissions,
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
