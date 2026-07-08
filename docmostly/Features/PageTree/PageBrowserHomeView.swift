import SwiftUI

struct PageBrowserHomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = PageBrowserViewModel()

    let space: DocmostSpace

    var body: some View {
        List {
            SpaceTitleHeaderView(space: space)
                .listRowInsets(PageBrowserMetrics.headerInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            PageBrowserScopeSwitch(viewModel: viewModel)
                .listRowInsets(PageBrowserMetrics.switchInsets)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)

            if viewModel.isLoading {
                ProgressView(viewModel.selectedScope.loadingTitle)
            }

            Section(viewModel.selectedScope.title) {
                ForEach(viewModel.items) { item in
                    PageOpenLink(target: PageOpenTarget(item: item)) {
                        PageBrowserRowView(item: item)
                    }
                    .listRowInsets(PageBrowserMetrics.rowInsets)
                    .listRowSeparator(.visible)
                }
            }

            if viewModel.items.isEmpty && viewModel.isLoading == false {
                ContentUnavailableView(
                    viewModel.selectedScope.emptyTitle,
                    systemImage: viewModel.selectedScope.emptySystemImage
                )
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(DocmostlyTheme.destructive)
            }
        }
        .task(id: pageBrowserTaskKey) {
            await viewModel.load(space: space, provider: appState)
        }
        .refreshable {
            await viewModel.load(space: space, provider: appState)
        }
        .pageOpenDestination()
    }

    private var pageBrowserTaskKey: PageBrowserTaskKey {
        PageBrowserTaskKey(spaceID: space.id, scope: viewModel.selectedScope)
    }
}
