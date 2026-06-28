import SwiftUI

struct MacCommandPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var query = ""
    @State private var searchViewModel = SearchViewModel()

    let items: [MacCommandPaletteItem]
    let openSearchResult: (DocmostSearchResult) -> Void
    let openSearchResultInNewWindow: (DocmostSearchResult) -> Void

    private var matchingItems: [MacCommandPaletteItem] {
        items.filter { $0.matches(query) }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "command")
                        .foregroundStyle(.secondary)

                    TextField("Search commands and pages", text: $query)
                        .textFieldStyle(.plain)
                }
                .padding()

                Divider()

                List {
                    if matchingItems.isEmpty == false {
                        Section("Commands") {
                            ForEach(matchingItems) { item in
                                Button {
                                    perform(item.action)
                                } label: {
                                    MacCommandPaletteCommandRow(item: item)
                                }
                                .buttonStyle(.plain)
                                .disabled(item.isEnabled == false)
                            }
                        }
                    }

                    if searchViewModel.isSearching {
                        ProgressView("Searching")
                    }

                    if searchViewModel.results.isEmpty == false {
                        Section("Pages") {
                            ForEach(searchViewModel.results) { result in
                                Button {
                                    dismiss()
                                    openSearchResult(result)
                                } label: {
                                    MacCommandPalettePageRow(result: result)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Open in New Window", systemImage: "macwindow") {
                                        dismiss()
                                        openSearchResultInNewWindow(result)
                                    }
                                }
                            }
                        }
                    }

                    if shouldShowNoResults {
                        ContentUnavailableView.search(text: query)
                    }

                    if let errorMessage = searchViewModel.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(DocmostlyTheme.destructive)
                    }
                }
                .listStyle(.inset)
            }
            .navigationTitle("Command Palette")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: dismiss.callAsFunction)
                }
            }
        }
        .frame(minWidth: 620, minHeight: 520)
        .task(id: query) {
            await searchPages(for: query)
        }
    }

    private var shouldShowNoResults: Bool {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedQuery.count >= 2
            && matchingItems.isEmpty
            && searchViewModel.results.isEmpty
            && searchViewModel.isSearching == false
            && searchViewModel.errorMessage == nil
    }

    private func searchPages(for query: String) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            searchViewModel.query = ""
            searchViewModel.results = []
            searchViewModel.errorMessage = nil
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(250))
            try Task.checkCancellation()
        } catch {
            return
        }

        searchViewModel.query = trimmedQuery
        await searchViewModel.search(appState: appState)
    }

    private func perform(_ action: @escaping @MainActor () -> Void) {
        dismiss()
        Task { @MainActor in
            await Task.yield()
            action()
        }
    }
}

private struct MacCommandPaletteCommandRow: View {
    let item: MacCommandPaletteItem

    var body: some View {
        HStack {
            Label {
                VStack(alignment: .leading) {
                    Text(item.title)
                        .foregroundStyle(item.isEnabled ? .primary : .secondary)

                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } icon: {
                Image(systemName: item.systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
            }

            Spacer()
        }
        .contentShape(.rect)
    }
}

private struct MacCommandPalettePageRow: View {
    let result: DocmostSearchResult

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Label {
                    Text(result.title.isEmpty ? "Untitled" : result.title)
                        .foregroundStyle(.primary)
                } icon: {
                    MacCommandPaletteResultIcon(icon: result.icon)
                }

                Text(result.space.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let highlight = result.highlight, highlight.isEmpty == false {
                    Text(highlight.removingHTMLTags())
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .contentShape(.rect)
    }
}

private struct MacCommandPaletteResultIcon: View {
    let icon: String?

    var body: some View {
        if let icon, icon.isEmpty == false {
            Text(icon)
        } else {
            Image(systemName: "doc.text")
                .foregroundStyle(.secondary)
        }
    }
}
