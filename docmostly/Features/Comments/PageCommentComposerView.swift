import SwiftUI

struct PageCommentComposerView: View {
    let draft: CommentComposerState
    let isSubmitting: Bool
    let isEnabled: Bool
    let postComment: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            Divider()

            CommentRichComposerView(
                draft: draft,
                placeholder: "Add a page comment",
                submitTitle: "Comment",
                accessibilityIdentifier: "page-comment-composer-field",
                isEnabled: isEnabled,
                isSubmitting: isSubmitting,
                autofocus: false,
                submit: postComment
            )
            .accessibilityIdentifier("page-comment-submit-button")
        }
    }
}
