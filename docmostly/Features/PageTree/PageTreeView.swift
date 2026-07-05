import SwiftUI

struct PageTreeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = PageTreeViewModel()
    @State private var browserViewModel = PageBrowserViewModel()
    @State private var creationRequest: PageCreationRequest?
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

    private func showSpaceSettings() {
        appState.selectSidebarUtilityDestination(.settings)
    }

    private func refreshPages() async {
        async let loadBrowser: Void = browserViewModel.load(space: space, provider: appState)
        async let loadSpaceActionState: Void = viewModel.loadSpaceActionState(spaceId: space.id, appState: appState)
        await loadBrowser
        await loadSpaceActionState
    }
}

private struct PageBrowserTaskKey: Hashable {
    let spaceID: String
    let scope: PageBrowserScope
}

private enum PageBrowserMetrics {
    static let rowHeight: CGFloat = 54
    static let iconWidth: CGFloat = 28
    static let rowInsets = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
    static let switchInsets = EdgeInsets(top: 8, leading: 12, bottom: 10, trailing: 12)
}

private struct PageBrowserScopeSwitch: View {
    @Bindable var viewModel: PageBrowserViewModel

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 18) {
                ForEach(PageBrowserScope.allCases) { scope in
                    Button {
                        viewModel.selectedScope = scope
                    } label: {
                        PageBrowserScopeLabel(
                            scope: scope,
                            isSelected: viewModel.selectedScope == scope
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(viewModel.selectedScope == scope ? .isSelected : [])
                }
            }
            .padding(.horizontal, 4)
        }
        .scrollIndicators(.hidden)
        .accessibilityElement(children: .contain)
    }
}

private struct PageBrowserScopeLabel: View {
    let scope: PageBrowserScope
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Label(scope.title, systemImage: scope.systemImage)
                .font(.callout)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Capsule()
                .fill(isSelected ? Color.primary : Color.clear)
                .frame(height: 2)
        }
        .padding(.top, 6)
        .contentShape(.rect)
    }
}

private struct PageBrowserRowView: View {
    let item: PageBrowserItem

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            PageBrowserItemIcon(icon: item.icon)

            VStack(alignment: .leading, spacing: 4) {
                Text(item.title)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                HStack(spacing: 6) {
                    Text(item.subtitle)

                    if let updatedAt = item.updatedAt {
                        Text(updatedAt.formatted(.relative(presentation: .named)))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, minHeight: PageBrowserMetrics.rowHeight, alignment: .leading)
        .contentShape(.rect)
    }
}

private struct PageBrowserItemIcon: View {
    let icon: String?

    var body: some View {
        Group {
            if let icon, icon.isEmpty == false {
                Text(icon)
                    .font(.title3)
                    .lineLimit(1)
            } else {
                Image(systemName: "doc.text")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: PageBrowserMetrics.iconWidth, height: PageBrowserMetrics.iconWidth)
        .accessibilityHidden(true)
    }
}

private struct PageBrowserDestinationView: View {
    @Environment(AppState.self) private var appState

    let item: PageBrowserItem

    var body: some View {
        PageReaderView(pageID: item.slugId)
            .task(id: item.id) {
                appState.selectPage(id: item.slugId, spaceID: item.spaceId)
            }
    }
}

struct PageTreeSpaceActionsMenu: View {
    @Environment(AppState.self) private var appState

    let space: DocmostSpace
    let viewModel: PageTreeViewModel
    let showTrash: () -> Void
    let showSpaceSettings: () -> Void

    var body: some View {
        Menu("Space Actions", systemImage: "ellipsis") {
            Button(favoriteTitle, systemImage: favoriteSystemImage, action: toggleFavorite)
                .disabled(viewModel.isTogglingSpaceFavorite || viewModel.isLoadingSpaceActions)

            Button(watchTitle, systemImage: watchSystemImage, action: toggleWatch)
                .disabled(viewModel.isTogglingSpaceWatch || viewModel.isLoadingSpaceActions)

            Divider()

            Button("Space Settings", systemImage: "gearshape", action: showSpaceSettings)

            Button("Trash", systemImage: "trash", role: .destructive, action: showTrash)
        }
        .labelStyle(.iconOnly)
    }

    private var favoriteTitle: String {
        viewModel.isFavoriteSpace ? "Remove from Favorites" : "Add to Favorites"
    }

    private var favoriteSystemImage: String {
        viewModel.isFavoriteSpace ? "star.slash" : "star"
    }

    private var watchTitle: String {
        viewModel.isWatchingSpace == true ? "Unwatch Space" : "Watch Space"
    }

    private var watchSystemImage: String {
        viewModel.isWatchingSpace == true ? "eye.slash" : "eye"
    }

    private func toggleFavorite() {
        Task {
            await viewModel.toggleSpaceFavorite(spaceId: space.id, appState: appState)
        }
    }

    private func toggleWatch() {
        Task {
            await viewModel.toggleSpaceWatch(spaceId: space.id, appState: appState)
        }
    }
}
