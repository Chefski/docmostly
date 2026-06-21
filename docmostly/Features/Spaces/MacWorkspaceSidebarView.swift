import SwiftUI

#if os(macOS)
struct MacWorkspaceSidebarView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = PageTreeViewModel()
    @State private var creationRequest: PageCreationRequest?
    @State private var moveRequest: PageTreeNode?
    @State private var copyRequest: PageTreeNode?
    @State private var isShowingTrash = false

    var body: some View {
        List {
            if let selectedSpace {
                Section {
                    MacSidebarSpacePickerRow(
                        selectedSpace: selectedSpace,
                        spaces: appState.spaces,
                        selectSpace: selectSpace
                    )

                    MacSidebarActionRow(
                        title: "Overview",
                        systemImage: "house",
                        isSelected: appState.selectedSidebarDestination == .space(selectedSpace.id)
                            && appState.selectedPageID == nil
                    ) {
                        appState.selectSpace(id: selectedSpace.id)
                    }

                    MacSidebarActionRow(
                        title: "Search",
                        systemImage: "magnifyingglass",
                        isSelected: appState.selectedSidebarDestination == .search && appState.selectedPageID == nil
                    ) {
                        appState.selectSidebarUtilityDestination(.search)
                    }

                    MacSidebarActionRow(
                        title: "Space settings",
                        systemImage: "gearshape",
                        isSelected: appState.selectedSidebarDestination == .settings && appState.selectedPageID == nil
                    ) {
                        appState.selectSidebarUtilityDestination(.settings)
                    }

                    MacSidebarActionRow(
                        title: "New page",
                        systemImage: "plus",
                        isSelected: false,
                        action: beginCreateRoot
                    )
                }

                Section {
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
                } header: {
                    MacSidebarPagesHeaderView(
                        space: selectedSpace,
                        viewModel: viewModel,
                        isPerformingAction: viewModel.isPerformingAction || viewModel.isPerformingSpaceAction,
                        showTrash: showTrash,
                        showSpaceSettings: showSpaceSettings,
                        createRoot: beginCreateRoot
                    )
                }
                .environment(\.defaultMinListRowHeight, PageTreeSidebarMetrics.rowHeight)
            } else {
                Text(appState.isOffline ? "No cached spaces" : "No spaces")
                    .foregroundStyle(.secondary)
            }

            if appState.isOffline {
                OfflineBadgeView(text: "Offline")
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Docmostly")
        .navigationSplitViewColumnWidth(min: 240, ideal: 280, max: 360)
        .task(id: selectedSpace?.id) {
            await loadSelectedSpacePages()
        }
        .sheet(item: $creationRequest) { request in
            PageCreationSheet(request: request) { title in
                await createPage(title: title, parentPageId: request.parentPageId)
            }
        }
        .sheet(item: $moveRequest) { node in
            PageMoveToSpaceSheet(
                page: node,
                currentSpaceId: node.spaceId,
                spaces: appState.spaces
            ) { targetSpaceId in
                let success = await viewModel.movePageToSpace(node, targetSpaceId: targetSpaceId, appState: appState)
                return success ? nil : viewModel.errorMessage ?? "Could not move this page."
            }
        }
        .sheet(item: $copyRequest) { node in
            PageCopySheet(
                page: node,
                currentSpaceId: node.spaceId,
                spaces: appState.spaces
            ) { targetSpaceId in
                let success = await viewModel.duplicatePage(node, targetSpaceId: targetSpaceId, appState: appState)
                return success ? nil : viewModel.errorMessage ?? "Could not duplicate this page."
            }
        }
        .sheet(isPresented: $isShowingTrash) {
            if let selectedSpace {
                PageTrashSheet(space: selectedSpace, viewModel: viewModel)
            } else {
                ContentUnavailableView("No Space Selected", systemImage: "square.stack.3d.up")
            }
        }
    }

    private var selectedSpace: DocmostSpace? {
        if let selectedSpaceID = appState.selectedSpaceID,
           let space = appState.spaces.first(where: { $0.id == selectedSpaceID }) {
            return space
        }

        return appState.spaces.first
    }

    private func loadSelectedSpacePages() async {
        guard let selectedSpace else {
            viewModel.nodes = []
            return
        }

        await viewModel.loadRoot(spaceId: selectedSpace.id, appState: appState)
        await viewModel.loadSpaceActionState(spaceId: selectedSpace.id, appState: appState)
    }

    private func selectSpace(_ space: DocmostSpace) {
        appState.selectSpace(id: space.id)
        Task {
            await loadSelectedSpacePages()
        }
    }

    private func beginCreateRoot() {
        guard let selectedSpace else { return }
        creationRequest = PageCreationRequest(parent: nil, spaceName: selectedSpace.name)
    }

    private func beginCreateChild(_ node: PageTreeNode) {
        creationRequest = PageCreationRequest(parent: node, spaceName: selectedSpace?.name ?? "")
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
        guard let selectedSpace else { return "No space selected." }
        let page = await viewModel.createPage(
            title: title,
            parentPageId: parentPageId,
            spaceId: selectedSpace.id,
            appState: appState
        )
        return page == nil ? viewModel.errorMessage ?? "Could not create this page." : nil
    }

    private func showTrash() {
        guard selectedSpace != nil else { return }
        isShowingTrash = true
    }

    private func showSpaceSettings() {
        appState.selectSidebarUtilityDestination(.settings)
    }
}

private struct MacSidebarSpacePickerRow: View {
    let selectedSpace: DocmostSpace
    let spaces: [DocmostSpace]
    let selectSpace: (DocmostSpace) -> Void

    var body: some View {
        Menu {
            ForEach(spaces) { space in
                Button(space.name) {
                    selectSpace(space)
                }
            }
        } label: {
            HStack {
                SpaceIconView(space: selectedSpace)

                Text(selectedSpace.name)
                    .bold()
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.down")
                    .foregroundStyle(.secondary)
                    .imageScale(.small)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct MacSidebarActionRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(isSelected ? DocmostlyTheme.primaryTint : Color.clear)
    }
}

private struct MacSidebarPagesHeaderView: View {
    let space: DocmostSpace
    let viewModel: PageTreeViewModel
    let isPerformingAction: Bool
    let showTrash: () -> Void
    let showSpaceSettings: () -> Void
    let createRoot: () -> Void

    var body: some View {
        HStack {
            Text("Pages")
                .font(.callout)
                .bold()

            Spacer()

            if isPerformingAction {
                ProgressView()
                    .controlSize(.small)
            }

            PageTreeSpaceActionsMenu(
                space: space,
                viewModel: viewModel,
                showTrash: showTrash,
                showSpaceSettings: showSpaceSettings
            )
            .buttonStyle(.borderless)
            .controlSize(.small)
            .imageScale(.medium)
            .foregroundStyle(.secondary)
            .help("Space actions")

            MacSidebarHeaderButton("New page", systemImage: "plus", action: createRoot)
        }
    }
}

private struct MacSidebarHeaderButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    init(_ title: String, systemImage: String, action: @escaping () -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.action = action
    }

    var body: some View {
        Button(title, systemImage: systemImage, action: action)
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .controlSize(.small)
            .imageScale(.medium)
            .foregroundStyle(.secondary)
            .help(title)
    }
}
#endif
