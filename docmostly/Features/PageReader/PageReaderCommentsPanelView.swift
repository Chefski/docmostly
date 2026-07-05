import SwiftUI

struct PageReaderCommentsPanelView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: PageReaderViewModel
    @State private var selectedTab = PageReaderCommentTab.open
    @State private var pendingDeleteComment: DocmostComment?

    let pageID: String
    let markInlineCommentResolved: (String, Bool) async -> Void
    let removeInlineComment: (String) async -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Picker("Comment Status", selection: $selectedTab) {
                ForEach(PageReaderCommentTab.allCases) { tab in
                    Text(tabLabel(for: tab)).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            ScrollView {
                LazyVStack(alignment: .leading) {
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
                            CommentThreadView(
                                comment: comment,
                                replies: viewModel.replies(for: comment.id),
                                isResolvingComment: viewModel.isResolvingComment,
                                canEditComment: canEdit,
                                canDeleteComment: canDelete,
                                canToggleResolved: appState.isOffline == false,
                                isEditingComment: viewModel.isEditingComment,
                                isUpdatingComment: viewModel.isUpdatingComment,
                                isDeletingComment: viewModel.isDeletingComment,
                                editDraft: editDraftBinding,
                                replyDraft: replyDraftBinding(for: comment.id),
                                isReplyComposerEnabled: appState.isOffline == false
                                    && comment.isLocallyQueued == false,
                                canPostReply: canPostReply(to: comment),
                                isPostingReply: viewModel.isPostingReply(to: comment.id),
                                toggleResolved: { _ in
                                    toggleResolved(comment)
                                },
                                beginEditing: { _ in
                                    viewModel.beginEditing(comment)
                                },
                                cancelEditing: { _ in
                                    viewModel.cancelEditing(commentID: comment.id)
                                },
                                saveEditing: { _ in
                                    updateComment(comment)
                                },
                                deleteComment: deleteComment,
                                postReply: {
                                    postReply(to: comment)
                                }
                            )
                        }
                    }

                    PageCommentComposerView(
                        draftComment: $viewModel.draftComment,
                        canPostComment: canPostComment,
                        postComment: postComment
                    )
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

    private func deleteComment(_ comment: DocmostComment) {
        pendingDeleteComment = comment
    }

    private func confirmDeleteComment() {
        guard let pendingDeleteComment else { return }
        self.pendingDeleteComment = nil
        Task {
            await viewModel.deleteComment(
                pendingDeleteComment,
                appState: appState,
                removeInlineComment: removeInlineComment
            )
        }
    }

    private func canPostReply(to comment: DocmostComment) -> Bool {
        appState.isOffline == false
            && viewModel.canSubmitReply(to: comment)
    }

    private func canEdit(_ comment: DocmostComment) -> Bool {
        appState.isOffline == false
            && comment.isNativelyEditable
            && canMutate(comment)
    }

    private func canDelete(_ comment: DocmostComment) -> Bool {
        appState.isOffline == false
            && appState.currentUserCanDeleteComment(comment)
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

private struct CommentThreadView: View {
    let comment: DocmostComment
    let replies: [DocmostComment]
    let isResolvingComment: (String) -> Bool
    let canEditComment: (DocmostComment) -> Bool
    let canDeleteComment: (DocmostComment) -> Bool
    let canToggleResolved: Bool
    let isEditingComment: (String) -> Bool
    let isUpdatingComment: (String) -> Bool
    let isDeletingComment: (String) -> Bool
    let editDraft: (String) -> Binding<String>
    let replyDraft: Binding<String>
    let isReplyComposerEnabled: Bool
    let canPostReply: Bool
    let isPostingReply: Bool
    let toggleResolved: (DocmostComment) -> Void
    let beginEditing: (DocmostComment) -> Void
    let cancelEditing: (DocmostComment) -> Void
    let saveEditing: (DocmostComment) -> Void
    let deleteComment: (DocmostComment) -> Void
    let postReply: () -> Void

    var body: some View {
        DocmostlyGlassPanel(cornerRadius: 12) {
            VStack(alignment: .leading) {
                CommentRowView(
                    comment: comment,
                    isReply: false,
                    isResolving: isResolvingComment(comment.id),
                    canToggleResolved: canToggleResolved,
                    canEdit: canEditComment(comment),
                    canDelete: canDeleteComment(comment),
                    isEditing: isEditingComment(comment.id),
                    isUpdating: isUpdatingComment(comment.id),
                    isDeleting: isDeletingComment(comment.id),
                    editDraft: editDraft(comment.id),
                    toggleResolved: {
                        toggleResolved(comment)
                    },
                    beginEditing: {
                        beginEditing(comment)
                    },
                    cancelEditing: {
                        cancelEditing(comment)
                    },
                    saveEditing: {
                        saveEditing(comment)
                    },
                    deleteComment: {
                        deleteComment(comment)
                    }
                )

                if replies.isEmpty == false {
                    VStack(alignment: .leading) {
                        ForEach(replies) { reply in
                            CommentRowView(
                                comment: reply,
                                isReply: true,
                                isResolving: isResolvingComment(reply.id),
                                canToggleResolved: false,
                                canEdit: canEditComment(reply),
                                canDelete: canDeleteComment(reply),
                                isEditing: isEditingComment(reply.id),
                                isUpdating: isUpdatingComment(reply.id),
                                isDeleting: isDeletingComment(reply.id),
                                editDraft: editDraft(reply.id),
                                toggleResolved: {},
                                beginEditing: {
                                    beginEditing(reply)
                                },
                                cancelEditing: {
                                    cancelEditing(reply)
                                },
                                saveEditing: {
                                    saveEditing(reply)
                                },
                                deleteComment: {
                                    deleteComment(reply)
                                }
                            )
                            .padding(.leading)
                        }
                    }
                }

                if comment.isResolved == false {
                    CommentReplyComposerView(
                        commentID: comment.id,
                        replyDraft: replyDraft,
                        isEnabled: isReplyComposerEnabled,
                        canPostReply: canPostReply,
                        isPostingReply: isPostingReply,
                        postReply: postReply
                    )
                }
            }
            .padding()
        }
    }
}

private struct CommentReplyComposerView: View {
    let commentID: String
    let replyDraft: Binding<String>
    let isEnabled: Bool
    let canPostReply: Bool
    let isPostingReply: Bool
    let postReply: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Divider()

            TextField("Write a reply", text: replyDraft, axis: .vertical)
                .lineLimit(2...)
                .textFieldStyle(.roundedBorder)
                .disabled(isEnabled == false || isPostingReply)
                .accessibilityIdentifier("comment-reply-field-\(commentID)")

            HStack {
                Spacer(minLength: 0)

                Button("Post Reply", systemImage: "arrowshape.turn.up.left", action: postReply)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .fixedSize(horizontal: true, vertical: false)
                    .disabled(canPostReply == false)
                    .accessibilityIdentifier("comment-reply-submit-\(commentID)")
            }
        }
        .padding(.top)
    }
}

private struct PageCommentComposerView: View {
    let draftComment: Binding<String>
    let canPostComment: Bool
    let postComment: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Divider()

            TextField("New page comment", text: draftComment, axis: .vertical)
                .lineLimit(3...)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("page-comment-composer-field")

            Button("Add Comment", systemImage: "text.bubble", action: postComment)
                .buttonStyle(.borderedProminent)
                .disabled(canPostComment == false)
                .accessibilityIdentifier("page-comment-submit-button")
        }
    }
}
