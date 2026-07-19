import SwiftUI

struct PageReaderCommentsPanelView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: PageReaderViewModel
    @State private var selectedTab = PageReaderCommentTab.open
    @State private var pendingDeleteComment: DocmostComment?
    @State private var scrollPosition = ScrollPosition()
    @AccessibilityFocusState private var accessibilityFocusedThreadID: String?

    let pageID: String
    let canComment: Bool
    let focusedCommentID: String?
    let focusInlineComment: (String) -> Void
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
                                viewModel: viewModel,
                                canComment: canComment,
                                isReplyEnabled: appState.isOffline == false,
                                focusedCommentID: focusedCommentID,
                                canEditComment: canEdit,
                                canDeleteComment: canDelete,
                                canToggleResolved: canToggleResolved,
                                toggleResolved: toggleResolved,
                                updateComment: updateComment,
                                deleteComment: requestDelete,
                                postReply: postReply,
                                focusInlineComment: focusInlineComment
                            )
                            .id(comment.id)
                            .accessibilityFocused($accessibilityFocusedThreadID, equals: comment.id)
                        }
                    }

                    if canComment {
                        PageCommentComposerView(
                            draft: viewModel.draftComment,
                            isSubmitting: viewModel.isPostingComment,
                            isEnabled: true,
                            postComment: postComment
                        )
                    } else {
                        Label("You can view comments on this page, but you cannot add one.", systemImage: "lock")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.vertical)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .scrollTargetLayout()
            }
            .scrollPosition($scrollPosition)
            .scrollIndicators(.hidden)

            if let errorMessage = viewModel.commentErrorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(DocmostlyTheme.destructive)
                    .accessibilityLabel("Comment error: \(errorMessage)")
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
        .task(id: focusedCommentID) {
            await focusRequestedThread()
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

    private func focusRequestedThread() async {
        guard let focusedCommentID,
              let rootComment = viewModel.rootComment(containing: focusedCommentID) else {
            return
        }

        selectedTab = rootComment.isResolved ? .resolved : .open
        await Task.yield()
        scrollPosition.scrollTo(id: rootComment.id, anchor: .center)
        accessibilityFocusedThreadID = rootComment.id
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

    private func postReply(_ comment: DocmostComment) {
        Task {
            await viewModel.postReply(to: comment, pageID: pageID, appState: appState)
        }
    }

    private func updateComment(_ comment: DocmostComment) {
        Task {
            await viewModel.updateComment(comment, appState: appState)
        }
    }

    private func requestDelete(_ comment: DocmostComment) {
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

    private func canEdit(_ comment: DocmostComment) -> Bool {
        CommentPermissionPolicy.canEdit(
            comment,
            currentUserID: appState.currentUser?.user.id,
            canComment: canComment,
            isOnline: appState.isOffline == false
        )
    }

    private func canDelete(_ comment: DocmostComment) -> Bool {
        CommentPermissionPolicy.canDelete(
            comment,
            currentUserID: appState.currentUser?.user.id,
            isSpaceAdmin: isSpaceAdmin(for: comment),
            isOnline: appState.isOffline == false
        )
    }

    private func canToggleResolved(_ comment: DocmostComment) -> Bool {
        CommentPermissionPolicy.canResolve(
            comment,
            canComment: canComment,
            isOnline: appState.isOffline == false
        )
    }

    private func isSpaceAdmin(for comment: DocmostComment) -> Bool {
        guard let spaceID = comment.spaceId else { return false }
        return appState.spaces.first { $0.id == spaceID }?.membership?.role == "admin"
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
