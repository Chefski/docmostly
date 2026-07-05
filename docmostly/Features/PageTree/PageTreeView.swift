import SwiftUI

struct PageTreeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = PageTreeViewModel()
    @State private var browserViewModel = PageBrowserViewModel()
    @State private var creationRequest: PageCreationRequest?
    @State private var moveRequest: PageTreeNode?
    @State private var copyRequest: PageTreeNode?
    @State private var isShowingTrash = false

    let space: DocmostSpace

    var body: some View {
        List {
            PageBrowserScopeSwitch(viewModel: browserViewModel)
                .listRowInsets(PageBrowserMetrics.switchInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if browserViewModel.isLoading {
                ProgressView(browserViewModel.selectedScope.loadingTitle)
            }

            ForEach(browserViewModel.items) { item in
                NavigationLink(value: item) {
                    PageBrowserRowView(item: item)
                }
                .listRowInsets(PageBrowserMetrics.rowInsets)
                .listRowSeparator(.visible)
            }

            if browserViewModel.items.isEmpty && browserViewModel.isLoading == false {
                ContentUnavailableView(
                    browserViewModel.selectedScope.emptyTitle,
                    systemImage: browserViewModel.selectedScope.emptySystemImage
                )
            }

            if let errorMessage = browserViewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(DocmostlyTheme.destructive)
            }

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
        .environment(\.defaultMinListRowHeight, PageBrowserMetrics.rowHeight)
        .navigationTitle(space.name)
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
                Button("New Page", systemImage: "plus", action: beginCreateRoot)
            }
        }
        .refreshable {
            await refreshPages()
        }
        .task(id: pageBrowserTaskKey) {
            await refreshPages()
        }
        .navigationDestination(for: PageBrowserItem.self) { item in
            PageBrowserDestinationView(item: item)
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
        PageBrowserTaskKey(spaceID: space.id, scope: browserViewModel.selectedScope)
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
        Task {
            await viewModel.toggle(node: node, appState: appState)
        }
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
        appState.selectSidebarUtilityDestination(.settings)
    }

    private func refreshPages() async {
        async let loadBrowser: Void = browserViewModel.load(space: space, provider: appState)
        async let loadRoot: Void = viewModel.loadRoot(spaceId: space.id, appState: appState)
        async let loadSpaceActionState: Void = viewModel.loadSpaceActionState(spaceId: space.id, appState: appState)
        await loadBrowser
        await loadRoot
        await loadSpaceActionState
    }
}
