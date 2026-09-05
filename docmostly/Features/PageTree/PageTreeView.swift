import SwiftUI

struct PageTreeView: View {
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @Environment(AppState.self) private var appState
    @State private var viewModel = PageTreeViewModel()
    @State private var browserViewModel = PageBrowserViewModel()
    @State private var searchViewModel = SearchViewModel()
    @State private var isSearchPresented = false
    @State private var creationRequest: PageCreationRequest?
    @State private var moveRequest: PageTreeNode?
    @State private var copyRequest: PageTreeNode?
    @State private var isShowingTrash = false
    @State private var initializedBrowserSpaceID: String?
    @State private var navigationState = PageTreeNavigationState()

    let space: DocmostSpace

    var body: some View {
        List {
            SpaceTitleHeaderView(space: space)
                .listRowInsets(PageBrowserMetrics.headerInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if isShowingSearch {
                SearchResultsContent(viewModel: searchViewModel, spaces: appState.spaces) {
                    await searchViewModel.loadMore(provider: searchProvider)
                }
            } else {
                RecentPagesRailView(
                    items: browserViewModel.items,
                    isLoading: browserViewModel.isLoading || initializedBrowserSpaceID != space.id,
                    errorMessage: browserViewModel.errorMessage,
                    isOffline: appState.isOffline
                )
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)

                if let spaceActionErrorMessage = viewModel.spaceActionErrorMessage {
                    Text(spaceActionErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(DocmostlyTheme.destructive)
                }

                Section("All Pages") {
                    if viewModel.isLoading && viewModel.nodes.isEmpty {
                        ProgressView("Loading pages")
                    }

                    ForEach(viewModel.visibleNodes) { visibleNode in
                        PageTreeNodeView(
                            node: visibleNode.node,
                            depth: visibleNode.depth,
                            isExpanded: visibleNode.isExpanded,
                            isSelected: appState.selectedPageID == visibleNode.node.slugId,
                            toggle: toggleNode,
                            openInDetailColumn: openInDetailColumn,
                            openInNewWindow: nil,
                            movePage: movePage,
                            createChild: beginCreateChild,
                            duplicate: beginDuplicate,
                            moveToSpace: beginMoveToSpace,
                            delete: deletePage
                        )
                        .transition(PageTreeBranchTransition())
                    }

                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(DocmostlyTheme.destructive)
                    }

                    if viewModel.nodes.isEmpty && viewModel.isLoading == false {
                        Text(appState.isOffline ? "No cached pages" : "No pages")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .environment(\.defaultMinListRowHeight, PageTreeSidebarMetrics.rowHeight)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if viewModel.isPerformingAction || viewModel.isPerformingSpaceAction {
                    ProgressView()
                }

                PageTreeSpaceActionsMenu(
                    space: space,
                    viewModel: viewModel,
                    showTrash: showTrash,
                    showSpaceSettings: showSpaceSettings
                )
                #if !os(iOS)
                Button("New Page", systemImage: "plus", action: beginCreateRoot)
                #endif
            }
            #if os(iOS)
            DefaultToolbarItem(kind: .search, placement: .bottomBar)
            ToolbarSpacer(.fixed, placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) {
                Button("New Page", systemImage: "square.and.pencil", action: beginCreateRoot)
            }
            #endif
        }
        #if os(iOS)
        .searchable(
            text: $searchViewModel.query,
            isPresented: $isSearchPresented,
            placement: .toolbar,
            prompt: "Search"
        )
        #endif
        .refreshable {
            await refreshPages()
        }
        .task(id: space.id) {
            await loadInitialSpaceState()
        }
        .task(id: pageBrowserTaskKey) {
            guard initializedBrowserSpaceID == space.id else { return }
            await refreshBrowser()
        }
        .task(id: searchTaskKey) {
            await searchViewModel.search(provider: searchProvider, debounce: .milliseconds(300))
        }
        .pageOpenDestination()
        .navigationDestination(for: PageTreeNode.self) { node in
            PageReaderDestinationView(pageID: node.slugId)
        }
        .navigationDestination(item: $navigationState.spaceSettingsSpaceID) { spaceID in
            SpaceSettingsDestinationView(spaceID: spaceID)
        }
        .sheet(item: $creationRequest) { request in
            PageCreationSheet(request: request) { title in
                await createPage(title: title, parentPageId: request.parentPageId)
            }
        }
        .sheet(item: $moveRequest) { node in
            PageMoveToSpaceSheet(
                page: node,
                currentSpaceId: space.id,
                spaces: appState.spaces
            ) { targetSpaceId in
                let success = await viewModel.movePageToSpace(node, targetSpaceId: targetSpaceId, appState: appState)
                if success {
                    await browserViewModel.load(space: space, provider: appState)
                }
                return success ? nil : viewModel.errorMessage ?? "Could not move this page."
            }
        }
        .sheet(item: $copyRequest) { node in
            PageCopySheet(
                page: node,
                currentSpaceId: space.id,
                spaces: appState.spaces
            ) { targetSpaceId in
                let success = await viewModel.duplicatePage(node, targetSpaceId: targetSpaceId, appState: appState)
                if success {
                    await browserViewModel.load(space: space, provider: appState)
                }
                return success ? nil : viewModel.errorMessage ?? "Could not duplicate this page."
            }
        }
        .sheet(isPresented: $isShowingTrash) {
            PageTrashSheet(space: space, viewModel: viewModel)
        }
    }

    private var pageBrowserTaskKey: PageBrowserTaskKey {
        PageBrowserTaskKey(
            spaceID: space.id,
            scope: browserViewModel.selectedScope,
            pageDiscoveryRevision: appState.pageDiscoveryRevision,
            favoriteRevision: appState.favoriteRevision,
            initializedSpaceID: initializedBrowserSpaceID
        )
    }

    private var searchTaskKey: PageTreeSearchTaskKey {
        PageTreeSearchTaskKey(spaceID: space.id, searchTaskKey: searchViewModel.taskKey(provider: searchProvider))
    }

    private var searchProvider: PageTreeSearchProvider {
        PageTreeSearchProvider(appState: appState, spaceID: space.id)
    }

    private var isShowingSearch: Bool {
        isSearchPresented || searchViewModel.query.isEmpty == false
    }

    private func beginCreateRoot() {
        creationRequest = PageCreationRequest(parent: nil, spaceName: space.name)
    }

    private func beginCreateChild(_ node: PageTreeNode) {
        creationRequest = PageCreationRequest(parent: node, spaceName: space.name)
    }

    private func beginDuplicate(_ node: PageTreeNode) {
        copyRequest = node
    }

    private func beginMoveToSpace(_ node: PageTreeNode) {
        moveRequest = node
    }

    private func deletePage(_ node: PageTreeNode) {
        Task {
            await viewModel.deletePage(node, appState: appState)
            await browserViewModel.load(space: space, provider: appState)
        }
    }

    private func toggleNode(_ node: PageTreeNode) {
        PageTreeExpansionMotion.toggle(
            node: node,
            viewModel: viewModel,
            appState: appState,
            reduceMotion: accessibilityReduceMotion
        )
    }

    private func openInDetailColumn(_ node: PageTreeNode) {
        appState.selectPage(id: node.slugId, spaceID: node.spaceId, revealSpaceInSidebar: true)
    }

    private func movePage(sourceID: String, operation: PageTreeDropOperation) {
        Task {
            await viewModel.movePage(sourceID: sourceID, operation: operation, appState: appState)
            await browserViewModel.load(space: space, provider: appState)
        }
    }

    private func createPage(title: String, parentPageId: String?) async -> String? {
        let page = await viewModel.createPage(
            title: title,
            parentPageId: parentPageId,
            spaceId: space.id,
            appState: appState
        )
        if page != nil {
            await browserViewModel.load(space: space, provider: appState)
        }
        return page == nil ? viewModel.errorMessage ?? "Could not create this page." : nil
    }

    private func showTrash() {
        isShowingTrash = true
    }

    private func showSpaceSettings() {
        navigationState.showSpaceSettings(spaceID: space.id)
    }

    private func refreshPages() async {
        async let loadBrowser: Void = refreshBrowser()
        async let loadTreeState: Void = refreshTreeState()
        await loadBrowser
        await loadTreeState
    }

    private func loadInitialSpaceState() async {
        initializedBrowserSpaceID = nil
        await viewModel.loadRoot(spaceId: space.id, appState: appState)
        guard Task.isCancelled == false else { return }

        initializedBrowserSpaceID = space.id

        await viewModel.loadSpaceActionState(spaceId: space.id, appState: appState)
    }

    private func refreshBrowser() async {
        browserViewModel.selectedScope = .recentlyUpdated
        await browserViewModel.load(
            space: space,
            provider: appState,
            limit: PageBrowserMetrics.railLimit
        )
    }

    private func refreshTreeState() async {
        async let loadRoot: Void = viewModel.loadRoot(spaceId: space.id, appState: appState)
        async let loadSpaceActionState: Void = viewModel.loadSpaceActionState(spaceId: space.id, appState: appState)
        await loadRoot
        await loadSpaceActionState
    }
}

private struct PageTreeSearchTaskKey: Hashable {
    let spaceID: String
    let searchTaskKey: SearchTaskKey
}

@MainActor
private final class PageTreeSearchProvider: SearchProviding {
    let appState: AppState
    let spaceID: String

    init(appState: AppState, spaceID: String) {
        self.appState = appState
        self.spaceID = spaceID
    }

    var selectedSpaceID: String? {
        spaceID
    }

    var currentSearchUserID: String? {
        appState.currentSearchUserID
    }

    func search(
        query: String,
        spaceId: String?,
        creatorId: String?,
        limit: Int,
        offset: Int
    ) async throws -> [DocmostSearchResult] {
        try await appState.search(
            query: query,
            spaceId: spaceId,
            creatorId: creatorId,
            limit: limit,
            offset: offset
        )
    }
}
