import SwiftUI

struct CommentReplyComposerView: View {
    let commentID: String
    let draft: CommentComposerState
    let isEnabled: Bool
    let isSubmitting: Bool
    let postReply: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Divider()

            CommentRichComposerView(
                draft: draft,
                placeholder: "Write a reply",
                submitTitle: "Reply",
                accessibilityIdentifier: "comment-reply-field-\(commentID)",
                isEnabled: isEnabled,
                isSubmitting: isSubmitting,
                autofocus: false,
                submit: postReply
            )
            .accessibilityIdentifier("comment-reply-submit-\(commentID)")
        }
        .padding(.top)
    }
}
