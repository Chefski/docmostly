import SwiftUI

struct CommentRowView: View {
    let comment: DocmostComment
    let isReply: Bool
    let isResolving: Bool
    let canToggleResolved: Bool
    let canEdit: Bool
    let canDelete: Bool
    let isEditing: Bool
    let isUpdating: Bool
    let isDeleting: Bool
    let editDraft: Binding<String>?
    let toggleResolved: () -> Void
    let beginEditing: () -> Void
    let cancelEditing: () -> Void
    let saveEditing: () -> Void
    let deleteComment: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.creator?.name ?? "Comment")
                        .font(.subheadline)
                        .bold()

                    if isReply {
                        Label("Reply", systemImage: "arrow.turn.down.right")
                            .labelStyle(.titleAndIcon)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if isEditing, let editDraft {
                    TextField("Edit comment", text: editDraft, axis: .vertical)
                        .lineLimit(2...)
                        .textFieldStyle(.roundedBorder)
                } else {
                    Text(comment.content ?? "")
                        .font(.body)
                        .foregroundStyle(comment.isResolved ? .secondary : .primary)
                }

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

                if isEditing {
                    HStack(spacing: 8) {
                        Button("Cancel", systemImage: "xmark", action: cancelEditing)
                            .controlSize(.small)

                        Button("Save", systemImage: "checkmark", action: saveEditing)
                            .controlSize(.small)
                            .disabled(isUpdating)
                    }
                    .buttonStyle(.bordered)
                }
            }

            Spacer(minLength: 0)

            Menu {
                if canEdit {
                    Button("Edit Comment", systemImage: "pencil", action: beginEditing)
                }

                if canToggleResolved {
                    Button(
                        comment.isResolved ? "Reopen Comment" : "Resolve Comment",
                        systemImage: comment.isResolved ? "checkmark.circle.fill" : "checkmark.circle",
                        action: toggleResolved
                    )
                    .disabled(isResolving)
                }

                if canDelete {
                    Button("Delete Comment", systemImage: "trash", role: .destructive, action: deleteComment)
                        .disabled(isDeleting)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .frame(width: 34, height: 34)
                    .contentShape(.rect)
                    .accessibilityLabel("Comment Actions")
            }
            .menuStyle(.button)
            .disabled((canEdit || canToggleResolved || canDelete) == false)
        }
        .padding(.vertical, 8)
    }
}
