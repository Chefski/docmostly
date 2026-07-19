import SwiftUI

struct CommentMentionPickerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var users: [DocmostMentionUserSuggestion] = []
    @State private var isSearching = false
    @State private var errorMessage: String?

    let draft: CommentComposerState

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    ProgressView("Searching people")
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(DocmostlyTheme.destructive)
                }

                ForEach(users) { user in
                    Button {
                        insert(user)
                    } label: {
                        VStack(alignment: .leading) {
                            Label(user.name.isEmpty ? "Unnamed person" : user.name, systemImage: "person.crop.circle")
                            if let email = user.email, email.isEmpty == false {
                                Text(email)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay {
                if query.isEmpty {
                    ContentUnavailableView("Search people", systemImage: "at")
                } else if users.isEmpty && isSearching == false && errorMessage == nil {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle("Mention Person")
            .searchable(text: $query, prompt: "Search people")
            .task(id: query) {
                await search()
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                }
            }
        }
        .frame(minWidth: 340, minHeight: 380)
    }

    private func search() async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedQuery.count >= 2 else {
            users = []
            errorMessage = nil
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(250))
            try Task.checkCancellation()
            isSearching = true
            errorMessage = nil
            defer { isSearching = false }
            let response = try await appState.searchMentionSuggestions(
                query: trimmedQuery,
                spaceId: appState.selectedSpaceID
            )
            try Task.checkCancellation()
            users = response.users
        } catch is CancellationError {
            return
        } catch {
            users = []
            errorMessage = error.localizedDescription
        }
    }

    private func insert(_ user: DocmostMentionUserSuggestion) {
        draft.insertMention(user, creatorID: appState.currentUser?.user.id)
        dismiss()
    }
}
