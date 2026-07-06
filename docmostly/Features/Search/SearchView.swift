import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SearchViewModel()

    var body: some View {
        List {
            SearchResultsContent(viewModel: viewModel, spaces: appState.spaces) {
                await viewModel.loadMore(provider: appState)
            }
        }
        .navigationTitle("Search")
        .searchable(text: $viewModel.query, prompt: "Search pages")
        .task(id: viewModel.searchTaskKey) {
            do {
                try await Task.sleep(for: .milliseconds(300))
                try Task.checkCancellation()
                await viewModel.search(provider: appState)
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
        .navigationDestination(for: DocmostSearchResult.self) { result in
            SearchResultDestinationView(result: result)
        }
    }
}

struct SearchResultsContent: View {
    @Bindable var viewModel: SearchViewModel
    let spaces: [DocmostSpace]
    let loadMore: () async -> Void

    var body: some View {
        SearchFilterBar(viewModel: viewModel, spaces: spaces)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

        if viewModel.isSearching {
            ProgressView("Searching")
        }

        ForEach(viewModel.results) { result in
            SearchResultRowView(result: result)
        }

        if viewModel.hasMoreResults {
            Button("Show More", systemImage: "chevron.down") {
                Task {
                    await loadMore()
                }
            }
            .disabled(viewModel.isLoadingMore)
        }

        if viewModel.isLoadingMore {
            ProgressView("Loading more")
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
}

private struct SearchFilterBar: View {
    @Bindable var viewModel: SearchViewModel
    let spaces: [DocmostSpace]

    var body: some View {
        Group {
            if #available(iOS 26.0, macOS 26.0, *) {
                GlassEffectContainer(spacing: 8) {
                    SearchFilterContent(viewModel: viewModel, spaces: spaces)
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
                }
            } else {
                SearchFilterContent(viewModel: viewModel, spaces: spaces)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: .rect(cornerRadius: 18))
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct SearchFilterContent: View {
    @Bindable var viewModel: SearchViewModel
    let spaces: [DocmostSpace]

    var body: some View {
        ViewThatFits {
            HStack {
                SearchSpacePicker(viewModel: viewModel, spaces: spaces)
                SearchAuthorPicker(viewModel: viewModel)
            }

            VStack(alignment: .leading) {
                SearchSpacePicker(viewModel: viewModel, spaces: spaces)
                SearchAuthorPicker(viewModel: viewModel)
            }
        }
        .controlSize(.small)
    }
}

private struct SearchSpacePicker: View {
    @Bindable var viewModel: SearchViewModel
    let spaces: [DocmostSpace]

    var body: some View {
        Picker("Space", selection: $viewModel.spaceScope) {
            Label("Current Space", systemImage: "sidebar.left")
                .tag(SearchSpaceScope.currentSpace)

            Label("All Spaces", systemImage: "square.stack.3d.up")
                .tag(SearchSpaceScope.allSpaces)

            ForEach(spaces) { space in
                Text(space.name)
                    .tag(SearchSpaceScope.space(space.id))
            }
        }
        .pickerStyle(.menu)
    }
}

private struct SearchAuthorPicker: View {
    @Bindable var viewModel: SearchViewModel

    var body: some View {
        Picker("Author", selection: $viewModel.authorScope) {
            Label("Anyone", systemImage: "person.2")
                .tag(SearchAuthorScope.anyone)

            Label("My Pages", systemImage: "person.crop.circle")
                .tag(SearchAuthorScope.currentUser)
        }
        .pickerStyle(.menu)
    }
}
