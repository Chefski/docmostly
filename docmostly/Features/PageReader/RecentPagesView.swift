import SwiftUI

struct RecentPagesView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = RecentPagesViewModel()

    var body: some View {
        List {
            if viewModel.isLoading {
                ProgressView("Loading recent pages")
            }

            Section(appState.isOffline ? "Recent cached pages" : "Recent pages") {
                ForEach(viewModel.pages) { page in
                    PageOpenLink(target: PageOpenTarget(page: page)) {
                        PageListRowView(page: page, systemImage: "clock")
                    }
                }
            }

            if viewModel.pages.isEmpty && viewModel.isLoading == false {
                ContentUnavailableView("No Recent Pages", systemImage: "clock")
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(DocmostlyTheme.destructive)
            }
        }
        .navigationTitle("Recent")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("Recent Actions", systemImage: "ellipsis.circle") {
                    Button("Refresh", systemImage: "arrow.clockwise") {
                        Task {
                            await viewModel.load(appState: appState)
                        }
                    }
                }
            }
        }
        .task {
            await viewModel.load(appState: appState)
        }
        .refreshable {
            await viewModel.load(appState: appState)
        }
        .pageOpenDestination()
    }
}
