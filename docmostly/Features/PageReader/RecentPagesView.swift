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
                    NavigationLink(value: page) {
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
            Button("Refresh", systemImage: "arrow.clockwise") {
                Task {
                    await viewModel.load(appState: appState)
                }
            }
        }
        .task {
            await viewModel.load(appState: appState)
        }
        .refreshable {
            await viewModel.load(appState: appState)
        }
        .navigationDestination(for: DocmostPage.self) { page in
            PageReaderView(pageID: page.slugId)
                .task(id: page.id) {
                    appState.selectedSpaceID = page.spaceId
                    appState.selectedPageID = page.slugId
                }
        }
    }
}
