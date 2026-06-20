import SwiftUI

struct PageTreeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = PageTreeViewModel()
    @State private var creationRequest: PageCreationRequest?
    @State private var moveRequest: PageTreeNode?
    @State private var copyRequest: PageTreeNode?
    @State private var isShowingTrash = false

    let space: DocmostSpace

    var body: some View {
        List {
            if viewModel.isLoading && viewModel.nodes.isEmpty {
                ProgressView("Loading pages")
            }

            ForEach(viewModel.nodes) { node in
                PageTreeNodeView(
                    node: node,
                    depth: 0,
                    viewModel: viewModel,
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
        .navigationTitle(space.name)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if viewModel.isPerformingAction {
                    ProgressView()
                }

                Button("Trash", systemImage: "trash", action: showTrash)
                Button("New Page", systemImage: "plus", action: beginCreateRoot)
            }
        }
        .refreshable {
            await viewModel.loadRoot(spaceId: space.id, appState: appState)
        }
        .task(id: space.id) {
            await viewModel.loadRoot(spaceId: space.id, appState: appState)
        }
        .navigationDestination(for: PageTreeNode.self) { node in
            PageReaderDestinationView(pageID: node.slugId)
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
                return success ? nil : viewModel.errorMessage ?? "Could not duplicate this page."
            }
        }
        .sheet(isPresented: $isShowingTrash) {
            PageTrashSheet(space: space, viewModel: viewModel)
        }
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
        }
    }

    private func createPage(title: String, parentPageId: String?) async -> String? {
        let page = await viewModel.createPage(
            title: title,
            parentPageId: parentPageId,
            spaceId: space.id,
            appState: appState
        )
        return page == nil ? viewModel.errorMessage ?? "Could not create this page." : nil
    }

    private func showTrash() {
        isShowingTrash = true
    }
}
