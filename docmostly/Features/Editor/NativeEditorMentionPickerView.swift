import SwiftUI

struct NativeEditorMentionPickerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: NativeRichEditorViewModel
    @State private var query = ""
    @State private var results: [DocmostSearchResult] = []
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    ProgressView("Searching")
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.secondary)
                }

                ForEach(results) { result in
                    Button {
                        insertMention(result)
                    } label: {
                        NativeEditorMentionResultRow(result: result)
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView("Search pages", systemImage: "at")
                } else if results.isEmpty && isSearching == false && errorMessage == nil {
                    ContentUnavailableView("No pages found", systemImage: "doc.text.magnifyingglass")
                }
            }
            .navigationTitle("Mention Page")
            .searchable(text: $query, prompt: "Search pages")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
            }
            .onSubmit(of: .search) {
                scheduleSearch()
            }
            .onChange(of: query) {
                scheduleSearch()
            }
            .onDisappear {
                searchTask?.cancel()
            }
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let query = query
        searchTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(250))
                await search(query: query)
            } catch {
                return
            }
        }
    }

    @MainActor
    private func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            results = []
            errorMessage = nil
            return
        }

        isSearching = true
        errorMessage = nil
        defer {
            isSearching = false
        }

        do {
            results = try await appState.search(query: trimmed, spaceId: appState.selectedSpaceID)
        } catch {
            results = []
            errorMessage = error.localizedDescription
        }
    }

    private func insertMention(_ result: DocmostSearchResult) {
        viewModel.insertMention(NativeEditorMention(pageSearchResult: result))
        dismiss()
    }
}

private struct NativeEditorMentionResultRow: View {
    let result: DocmostSearchResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(result.title.isEmpty ? "Untitled" : result.title)
                    .foregroundStyle(.primary)
            } icon: {
                if let icon = result.icon, icon.isEmpty == false {
                    Text(icon)
                } else {
                    Image(systemName: "doc.text")
                }
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}
