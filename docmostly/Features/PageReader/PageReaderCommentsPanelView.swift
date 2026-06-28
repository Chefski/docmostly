import SwiftUI

struct PageReaderCommentsPanelView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: PageReaderViewModel
    @State private var selectedTab = PageReaderCommentTab.open

    let pageID: String
    let markInlineCommentResolved: (String, Bool) async -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Comment Status", selection: $selectedTab) {
                ForEach(PageReaderCommentTab.allCases) { tab in
                    Text(tabLabel(for: tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if visibleComments.isEmpty {
                        ContentUnavailableView(
                            emptyTitle,
                            systemImage: "text.bubble",
                            description: Text(emptyDescription)
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                    } else {
                        ForEach(visibleComments) { comment in
                            CommentRowView(
                                comment: comment,
                                isResolving: viewModel.isResolvingComment(id: comment.id),
                                canToggleResolved: appState.isOffline == false,
                                toggleResolved: {
                                    toggleResolved(comment)
                                }
                            )
                            .padding()
                            .background(.quaternary.opacity(0.18), in: .rect(cornerRadius: 8))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)

            TextField("Add a page comment", text: $viewModel.draftComment, axis: .vertical)
                .lineLimit(3...)
                .textFieldStyle(.roundedBorder)

            Button("Add Comment", systemImage: "text.bubble", action: postComment)
                .buttonStyle(.borderedProminent)
                .disabled(canPostComment == false)

            if let errorMessage = viewModel.commentErrorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(DocmostlyTheme.destructive)
            }
        }
    }

    private var visibleComments: [DocmostComment] {
        switch selectedTab {
        case .open:
            viewModel.openComments
        case .resolved:
            viewModel.resolvedComments
        }
    }

    private var emptyTitle: String {
        switch selectedTab {
        case .open:
            "No open comments"
        case .resolved:
            "No resolved comments"
        }
    }

    private var emptyDescription: String {
        switch selectedTab {
        case .open:
            "Open page and inline comments will appear here."
        case .resolved:
            "Resolved comments will appear here."
        }
    }

    private func tabLabel(for tab: PageReaderCommentTab) -> String {
        switch tab {
        case .open:
            "\(tab.title) \(viewModel.openCommentCount)"
        case .resolved:
            "\(tab.title) \(viewModel.resolvedCommentCount)"
        }
    }

    private func postComment() {
        Task {
            await viewModel.postComment(pageID: pageID, appState: appState)
        }
    }

    private var canPostComment: Bool {
        viewModel.draftComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && viewModel.isPostingComment == false
    }

    private func toggleResolved(_ comment: DocmostComment) {
        Task {
            await viewModel.toggleResolved(
                comment,
                pageID: pageID,
                appState: appState,
                markInlineCommentResolved: markInlineCommentResolved
            )
        }
    }
}
