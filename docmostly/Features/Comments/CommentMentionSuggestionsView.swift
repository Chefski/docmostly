import SwiftUI

struct CommentMentionSuggestionsView: View {
    @Environment(AppState.self) private var appState
    @State private var users: [DocmostMentionUserSuggestion] = []
    @State private var isSearching = false

    let query: String
    let draft: CommentComposerState

    var body: some View {
        Group {
            if isSearching {
                ProgressView()
                    .controlSize(.small)
            } else if users.isEmpty == false {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(users.prefix(5)) { user in
                            Button(user.name, systemImage: "person.crop.circle") {
                                draft.insertMention(user, creatorID: appState.currentUser?.user.id)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .accessibilityLabel("Mention suggestions")
        .task(id: query) {
            await search()
        }
    }

    private func search() async {
        guard query.count >= 2 else {
            users = []
            return
        }

        do {
            try await Task.sleep(for: .milliseconds(250))
            try Task.checkCancellation()
            isSearching = true
            defer { isSearching = false }
            let response = try await appState.searchMentionSuggestions(
                query: query,
                spaceId: appState.selectedSpaceID,
                limit: 5
            )
            try Task.checkCancellation()
            users = response.users
        } catch {
            users = []
        }
    }
}
