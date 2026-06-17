import SwiftUI

struct CommentRowView: View {
    let comment: DocmostComment
    let isResolving: Bool
    let canToggleResolved: Bool
    let toggleResolved: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(comment.creator?.name ?? "Comment")
                    .font(.subheadline)
                    .bold()

                Text(comment.content ?? "")
                    .font(.body)
                    .foregroundStyle(comment.isResolved ? .secondary : .primary)

                HStack(spacing: 8) {
                    if let createdAt = comment.createdAt {
                        Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                    }

                    if comment.isResolved {
                        Label("Resolved", systemImage: "checkmark.seal.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(
                comment.isResolved ? "Reopen" : "Resolve",
                systemImage: comment.isResolved ? "checkmark.circle.fill" : "checkmark.circle",
                action: toggleResolved
            )
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isResolving || canToggleResolved == false)
        }
        .padding(.vertical, 8)
    }
}
