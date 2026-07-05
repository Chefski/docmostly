import SwiftUI

struct SearchView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = SearchViewModel()

    var body: some View {
        List {
            SearchFilterBar(viewModel: viewModel, spaces: appState.spaces)
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
                        await viewModel.loadMore(provider: appState)
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

private struct SearchFilterBar: View {
    @Bindable var viewModel: SearchViewModel
    let spaces: [DocmostSpace]

    var body: some View {
        Group {
            if #available(iOS 26.0, macOS 26.0, *) {
                GlassEffectContainer(spacing: 8) {
                    filterContent
                        .padding(.horizontal)
                        .padding(.vertical, 10)
                        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 18))
                }
            } else {
                filterContent
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: .rect(cornerRadius: 18))
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var filterContent: some View {
        ViewThatFits {
            HStack {
                spacePicker
                authorPicker
            }

            VStack(alignment: .leading) {
                spacePicker
                authorPicker
            }
        }
        .controlSize(.small)
    }

    private var spacePicker: some View {
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

    private var authorPicker: some View {
        Picker("Author", selection: $viewModel.authorScope) {
            Label("Anyone", systemImage: "person.2")
                .tag(SearchAuthorScope.anyone)

            Label("My Pages", systemImage: "person.crop.circle")
                .tag(SearchAuthorScope.currentUser)
        }
        .pickerStyle(.menu)
    }
}
