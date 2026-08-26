import SwiftUI

struct SidebarPageBrowserSection: View {
    @Bindable var viewModel: PageBrowserViewModel

    var body: some View {
        Group {
            Section {
                PageBrowserScopeSwitch(viewModel: viewModel)
                    .contentMargins(
                        .horizontal,
                        PageBrowserMetrics.sidebarScopeSwitchSidePadding,
                        for: .scrollContent
                    )
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            .listSectionMargins(.horizontal, 0)

            Section {
                if viewModel.isLoading && viewModel.items.isEmpty {
                    ProgressView(viewModel.selectedScope.loadingTitle)
                        .frame(maxWidth: .infinity)
                } else if viewModel.items.isEmpty {
                    ContentUnavailableView(
                        viewModel.selectedScope.emptyTitle,
                        systemImage: viewModel.selectedScope.emptySystemImage
                    )
                } else {
                    ForEach(viewModel.items) { item in
                        PageOpenLink(target: PageOpenTarget(item: item)) {
                            PageBrowserRowView(item: item)
                        }
                        .listRowInsets(PageBrowserMetrics.rowInsets)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(DocmostlyTheme.destructive)
                }
            }
        }
    }
}
