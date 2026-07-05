import SwiftUI

struct PageReaderCommentsPanelView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: PageReaderViewModel
    @State private var selectedTab = PageReaderCommentTab.open
    @State private var pendingDeleteComment: DocmostComment?

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
                            commentThread(for: comment)
                        }
                    }

                    pageCommentComposer
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)

            if let errorMessage = viewModel.commentErrorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(DocmostlyTheme.destructive)
            }
        }
        .confirmationDialog("Delete this comment?", isPresented: deleteConfirmationBinding) {
            Button("Delete Comment", role: .destructive, action: confirmDeleteComment)
            Button("Cancel", role: .cancel) {
                pendingDeleteComment = nil
            }
        } message: {
            Text("Replies in this thread will also be removed.")
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

    private func commentThread(for comment: DocmostComment) -> some View {
        DocmostlyGlassPanel(cornerRadius: 12) {
            VStack(alignment: .leading, spacing: 10) {
                commentRow(for: comment, isReply: false)

                let replies = viewModel.replies(for: comment.id)
                if replies.isEmpty == false {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(replies) { reply in
                            commentRow(for: reply, isReply: true)
                                .padding(.leading)
                        }
                    }
                }

                if comment.isResolved == false {
                    replyComposer(for: comment)
                }
            }
            .padding(12)
        }
    }

    private var pageCommentComposer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            TextField("New page comment", text: $viewModel.draftComment, axis: .vertical)
                .lineLimit(3...)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("page-comment-composer-field")

            Button("Add Comment", systemImage: "text.bubble", action: postComment)
                .buttonStyle(.borderedProminent)
                .disabled(canPostComment == false)
                .accessibilityIdentifier("page-comment-submit-button")
        }
    }

    private func commentRow(for comment: DocmostComment, isReply: Bool) -> some View {
        CommentRowView(
            comment: comment,
            isReply: isReply,
            isResolving: viewModel.isResolvingComment(id: comment.id),
            canToggleResolved: isReply == false && appState.isOffline == false,
            canEdit: canMutate(comment),
            canDelete: canMutate(comment) && appState.isOffline == false,
            isEditing: viewModel.isEditingComment(id: comment.id),
            isUpdating: viewModel.isUpdatingComment(id: comment.id),
            isDeleting: viewModel.isDeletingComment(id: comment.id),
            editDraft: editDraftBinding(for: comment.id),
            toggleResolved: {
                toggleResolved(comment)
            },
            beginEditing: {
                viewModel.beginEditing(comment)
            },
            cancelEditing: {
                viewModel.cancelEditing(commentID: comment.id)
            },
            saveEditing: {
                updateComment(comment)
            },
            deleteComment: {
                pendingDeleteComment = comment
            }
        )
    }

    private func replyComposer(for comment: DocmostComment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            TextField("Write a reply", text: replyDraftBinding(for: comment.id), axis: .vertical)
                .lineLimit(2...)
                .textFieldStyle(.roundedBorder)
                .disabled(appState.isOffline)
                .accessibilityIdentifier("comment-reply-field-\(comment.id)")

            HStack {
                Spacer(minLength: 0)

                Button("Post Reply", systemImage: "arrowshape.turn.up.left", action: {
                    postReply(to: comment)
                })
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .fixedSize(horizontal: true, vertical: false)
                .disabled(canPostReply(to: comment) == false)
                .accessibilityIdentifier("comment-reply-submit-\(comment.id)")
            }
        }
        .padding(.top, 4)
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

    private func postReply(to comment: DocmostComment) {
        Task {
            await viewModel.postReply(to: comment, pageID: pageID, appState: appState)
        }
    }

    private func updateComment(_ comment: DocmostComment) {
        Task {
            await viewModel.updateComment(comment, appState: appState)
        }
    }

    private func confirmDeleteComment() {
        guard let pendingDeleteComment else { return }
        self.pendingDeleteComment = nil
        Task {
            await viewModel.deleteComment(pendingDeleteComment, appState: appState)
        }
    }

    private func canPostReply(to comment: DocmostComment) -> Bool {
        appState.isOffline == false
            && viewModel.isPostingReply(to: comment.id) == false
            && (viewModel.replyDraftsByCommentID[comment.id] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty == false
    }

    private func canMutate(_ comment: DocmostComment) -> Bool {
        appState.currentUser?.user.id == comment.creatorId
    }

    private func replyDraftBinding(for commentID: String) -> Binding<String> {
        Binding {
            viewModel.replyDraftsByCommentID[commentID] ?? ""
        } set: { newValue in
            viewModel.replyDraftsByCommentID[commentID] = newValue
        }
    }

    private func editDraftBinding(for commentID: String) -> Binding<String> {
        Binding {
            viewModel.editDraftsByCommentID[commentID] ?? ""
        } set: { newValue in
            viewModel.editDraftsByCommentID[commentID] = newValue
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding {
            pendingDeleteComment != nil
        } set: { isPresented in
            if isPresented == false {
                pendingDeleteComment = nil
            }
        }
    }
}
