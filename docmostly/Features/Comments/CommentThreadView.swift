import SwiftUI

struct CommentThreadView: View {
    let comment: DocmostComment
    let replies: [DocmostComment]
    let viewModel: PageReaderViewModel
    let canComment: Bool
    let isReplyEnabled: Bool
    let focusedCommentID: String?
    let canEditComment: (DocmostComment) -> Bool
    let canDeleteComment: (DocmostComment) -> Bool
    let canToggleResolved: (DocmostComment) -> Bool
    let toggleResolved: (DocmostComment) -> Void
    let updateComment: (DocmostComment) -> Void
    let deleteComment: (DocmostComment) -> Void
    let postReply: (DocmostComment) -> Void
    let focusInlineComment: (String) -> Void

    var body: some View {
        DocmostlyGlassPanel(cornerRadius: 12) {
            VStack(alignment: .leading) {
                commentRow(comment, isReply: false)

                if replies.isEmpty == false {
                    VStack(alignment: .leading) {
                        ForEach(replies) { reply in
                            commentRow(reply, isReply: true)
                                .padding(.leading)
                        }
                    }
                }

                if comment.isResolved == false, canComment {
                    CommentReplyComposerView(
                        commentID: comment.id,
                        draft: viewModel.replyDraft(for: comment.id),
                        isEnabled: isReplyEnabled && comment.isLocallyQueued == false,
                        isSubmitting: viewModel.isPostingReply(to: comment.id),
                        postReply: {
                            postReply(comment)
                        }
                    )
                }
            }
            .padding()
        }
    }

    private func commentRow(_ rowComment: DocmostComment, isReply: Bool) -> some View {
        CommentRowView(
            comment: rowComment,
            isReply: isReply,
            isResolving: viewModel.isResolvingComment(id: rowComment.id),
            canToggleResolved: canToggleResolved(rowComment),
            canEdit: canEditComment(rowComment),
            canDelete: canDeleteComment(rowComment),
            isEditing: viewModel.isEditingComment(id: rowComment.id),
            isUpdating: viewModel.isUpdatingComment(id: rowComment.id),
            isDeleting: viewModel.isDeletingComment(id: rowComment.id),
            editDraft: viewModel.editDraftsByCommentID[rowComment.id],
            errorMessage: viewModel.commentErrorsByID[rowComment.id],
            isFocused: focusedCommentID == rowComment.id,
            toggleResolved: {
                toggleResolved(rowComment)
            },
            beginEditing: {
                viewModel.beginEditing(rowComment)
            },
            cancelEditing: {
                viewModel.cancelEditing(commentID: rowComment.id)
            },
            saveEditing: {
                updateComment(rowComment)
            },
            deleteComment: {
                deleteComment(rowComment)
            },
            focusInlineComment: {
                focusInlineComment(rowComment.id)
            }
        )
    }
}
