import SwiftUI

struct CommentBodyView: View {
    let comment: DocmostComment

    var body: some View {
        Text(comment.body?.attributedText ?? AttributedString(comment.content ?? ""))
            .font(.body)
            .foregroundStyle(comment.isResolved ? .secondary : .primary)
            .textSelection(.enabled)
            .accessibilityLabel(comment.content ?? "Comment")
    }
}
