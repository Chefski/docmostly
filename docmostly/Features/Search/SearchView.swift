import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SearchViewModel()

    var body: some View {
        List {
            if viewModel.isSearching {
                ProgressView("Searching")
            }

            ForEach(viewModel.results) { result in
                SearchResultRowView(result: result)
            }

            if viewModel.results.isEmpty && viewModel.query.isEmpty == false && viewModel.isSearching == false {
                ContentUnavailableView.search(text: viewModel.query)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(DocmostlyTheme.destructive)
            }
        }
        .navigationTitle("Search")
        .searchable(text: $viewModel.query, prompt: "Search pages")
        .task(id: viewModel.query) {
            try? await Task.sleep(for: .milliseconds(300))
            await viewModel.search(appState: appState)
        }
        .navigationDestination(for: DocmostSearchResult.self) { result in
            SearchResultDestinationView(result: result)
        }
    }
}
