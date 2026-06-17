import SwiftUI

struct CommentRowView: View {
    let comment: DocmostComment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(comment.creator?.name ?? "Comment")
                .font(.subheadline)
                .bold()
            Text(comment.content ?? "")
                .font(.body)
                .foregroundStyle(.primary)
            if let createdAt = comment.createdAt {
                Text(createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}
