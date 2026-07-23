import SwiftData
import Testing
@testable import docmostly

@MainActor
struct PageTreeViewModelRefreshTests {
    @Test func expandedParentDropsStaleDisclosureWhenRefreshedChildrenAreEmpty() async throws {
        let container = DocmostlyModelContainer.make(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let appState = AppState()
        let scope = CacheScope(serverBaseURL: "https://docs.example.com", userID: "user-1")
        appState.configure(modelContext: context, modelContainer: container)
        appState.configurePreviewCacheScope(scope)
        let repository = try #require(appState.cacheRepository)
        try repository.savePageTree(
            spaceId: "space-1",
            parentPageId: nil,
            pages: [page(id: "parent", parentPageId: nil, hasChildren: true)],
            scope: scope
        )
        try repository.savePageTree(
            spaceId: "space-1",
            parentPageId: "parent",
            pages: [],
            scope: scope
        )
        let viewModel = PageTreeViewModel()

        await viewModel.loadRoot(spaceId: "space-1", appState: appState)
        await viewModel.toggle(node: try #require(viewModel.nodes.first), appState: appState)
        #expect(viewModel.nodes.first?.hasChildren == false)

        await viewModel.loadRoot(spaceId: "space-1", appState: appState)

        #expect(viewModel.nodes.first?.hasChildren == false)
        #expect(viewModel.nodes.first?.isChildrenLoaded == true)
    }

    private func page(id: String, parentPageId: String?, hasChildren: Bool) -> DocmostPage {
        DocmostPage(
            id: id,
            slugId: id,
            title: "Parent",
            content: nil,
            icon: nil,
            coverPhoto: nil,
            parentPageId: parentPageId,
            creatorId: nil,
            spaceId: "space-1",
            workspaceId: "workspace-1",
            isLocked: false,
            lastUpdatedById: nil,
            createdAt: nil,
            updatedAt: nil,
            deletedAt: nil,
            position: "a0",
            hasChildren: hasChildren,
            permissions: nil,
            creator: nil,
            lastUpdatedBy: nil,
            contributors: nil,
            space: nil
        )
    }
}
