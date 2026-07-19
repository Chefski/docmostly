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
    let editDraft: CommentComposerState?
    let errorMessage: String?
    let isFocused: Bool
    let toggleResolved: () -> Void
    let beginEditing: () -> Void
    let cancelEditing: () -> Void
    let saveEditing: () -> Void
    let deleteComment: () -> Void
    let focusInlineComment: () -> Void

    var body: some View {
        HStack(alignment: .top) {
            CommentAvatarView(name: comment.creator?.name)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(comment.creator?.name ?? "Comment")
                        .font(.subheadline)
                        .bold()

                    if isReply {
                        Label("Reply", systemImage: "arrow.turn.down.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if isReply == false,
                   let selection = comment.selection?.trimmingCharacters(in: .whitespacesAndNewlines),
                   selection.isEmpty == false {
                    Button(action: focusInlineComment) {
                        Label {
                            Text(selection)
                                .lineLimit(4)
                        } icon: {
                            Image(systemName: "quote.opening")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial, in: .rect(cornerRadius: 8))
                    .accessibilityLabel("Commented text: \(selection)")
                }

                if isEditing, let editDraft {
                    CommentRichComposerView(
                        draft: editDraft,
                        placeholder: "Edit comment",
                        submitTitle: "Save",
                        accessibilityIdentifier: "comment-edit-field-\(comment.id)",
                        isEnabled: true,
                        isSubmitting: isUpdating,
                        autofocus: true,
                        submit: saveEditing,
                        cancel: cancelEditing
                    )
                } else {
                    CommentBodyView(comment: comment)
                }

                CommentStateMetadataView(comment: comment)

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(DocmostlyTheme.destructive)
                }
            }

            Spacer(minLength: 0)

            Menu("Comment Actions", systemImage: "ellipsis.circle") {
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
            }
            .labelStyle(.iconOnly)
            .menuStyle(.button)
            .disabled((canEdit || canToggleResolved || canDelete) == false)
            .accessibilityLabel("Comment Actions")
        }
        .padding(.vertical, 8)
        .padding(.horizontal, isFocused ? 8 : 0)
        .background(isFocused ? DocmostlyTheme.primaryTint : .clear, in: .rect(cornerRadius: 8))
        .accessibilityAddTraits(isFocused ? .isSelected : [])
    }
}

private struct CommentAvatarView: View {
    let name: String?

    var body: some View {
        Text(initials)
            .font(.caption)
            .bold()
            .foregroundStyle(DocmostlyTheme.primary)
            .frame(width: 30, height: 30)
            .background(DocmostlyTheme.primaryTint, in: .circle)
            .accessibilityLabel(name ?? "Comment author")
    }

    private var initials: String {
        let parts = (name ?? "?").split(separator: " ").prefix(2)
        let value = parts.compactMap(\.first).map(String.init).joined()
        return value.isEmpty ? "?" : value.uppercased()
    }
}

private struct CommentStateMetadataView: View {
    let comment: DocmostComment

    var body: some View {
        HStack {
            if let createdAt = comment.createdAt {
                Text(createdAt.formatted(date: .abbreviated, time: .shortened))
            }

            if comment.editedAt != nil {
                Label("Edited", systemImage: "pencil")
            }

            if comment.isLocallyQueued {
                Label("Queued", systemImage: "clock.arrow.circlepath")
            }

            if comment.isResolved {
                Label("Resolved", systemImage: "checkmark.seal.fill")
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}
