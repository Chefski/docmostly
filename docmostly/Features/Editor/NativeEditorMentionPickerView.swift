import SwiftUI

struct NativeEditorMentionPickerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: NativeRichEditorViewModel
    @State private var query = ""
    @State private var suggestions = DocmostMentionSuggestionResponse()
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

                if suggestions.users.isEmpty == false {
                    Section("People") {
                        ForEach(suggestions.users) { user in
                            Button {
                                insertMention(user)
                            } label: {
                                NativeEditorMentionUserSuggestionRow(user: user)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if suggestions.pages.isEmpty == false {
                    Section("Pages") {
                        ForEach(suggestions.pages) { page in
                            Button {
                                insertMention(page)
                            } label: {
                                NativeEditorMentionPageSuggestionRow(page: page)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .overlay {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView("Search people and pages", systemImage: "at")
                } else if suggestions.isEmpty && isSearching == false && errorMessage == nil {
                    ContentUnavailableView("No mention results", systemImage: "doc.text.magnifyingglass")
                }
            }
            .navigationTitle("Mention")
            .searchable(text: $query, prompt: "Search people and pages")
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
                try Task.checkCancellation()
                await search(query: query)
            } catch is CancellationError {
                return
            } catch {
                return
            }
        }
    }

    @MainActor
    private func search(query: String) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            suggestions = DocmostMentionSuggestionResponse()
            errorMessage = nil
            return
        }

        isSearching = true
        errorMessage = nil
        defer {
            isSearching = false
        }

        do {
            let fetchedSuggestions = try await appState.searchMentionSuggestions(
                query: trimmed,
                spaceId: appState.selectedSpaceID
            )
            guard Task.isCancelled == false else { return }
            guard trimmed == self.query.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
            suggestions = fetchedSuggestions
        } catch {
            guard Task.isCancelled == false else { return }
            suggestions = DocmostMentionSuggestionResponse()
            errorMessage = error.localizedDescription
        }
    }

    private func insertMention(_ user: DocmostMentionUserSuggestion) {
        viewModel.insertMention(NativeEditorMention(
            userSuggestion: user,
            creatorID: appState.currentUser?.user.id
        ))
        dismiss()
    }

    private func insertMention(_ page: DocmostMentionPageSuggestion) {
        viewModel.insertMention(NativeEditorMention(
            pageSuggestion: page,
            creatorID: appState.currentUser?.user.id
        ))
        dismiss()
    }
}

private struct NativeEditorMentionUserSuggestionRow: View {
    let user: DocmostMentionUserSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(user.name.isEmpty ? "Unnamed person" : user.name)
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: "person.crop.circle")
            }

            if let email = user.email, email.isEmpty == false {
                Text(email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}

private struct NativeEditorMentionPageSuggestionRow: View {
    let page: DocmostMentionPageSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label {
                Text(page.title.isEmpty ? "Untitled" : page.title)
                    .foregroundStyle(.primary)
            } icon: {
                if let icon = page.icon, icon.isEmpty == false {
                    Text(icon)
                } else {
                    Image(systemName: "doc.text")
                }
            }

            if let spaceName = page.space?.name, spaceName.isEmpty == false {
                Text(spaceName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }
}
