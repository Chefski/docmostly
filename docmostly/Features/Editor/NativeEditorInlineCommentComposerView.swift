import SwiftUI

struct NativeEditorInlineCommentComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft = CommentComposerState()
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    let selectedText: String
    let submit: (CommentBody) async throws -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
                NativeEditorInlineCommentSelectionView(text: selectedText)

                CommentRichComposerView(
                    draft: draft,
                    placeholder: "Add an inline comment",
                    submitTitle: "Add",
                    accessibilityIdentifier: "inline-comment-field",
                    isEnabled: true,
                    isSubmitting: isSubmitting,
                    autofocus: true,
                    submit: addComment,
                    cancel: dismiss.callAsFunction
                )

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(DocmostlyTheme.destructive)
                }

                Spacer(minLength: 0)
            }
            .padding()
            .background(.background)
            .navigationTitle("Inline Comment")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .presentationDetents([.medium, .large])
    }

    private func addComment() {
        guard draft.isEmpty == false else { return }
        let body = draft.body

        Task {
            isSubmitting = true
            errorMessage = nil
            defer { isSubmitting = false }

            do {
                try await submit(body)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct NativeEditorInlineCommentSelectionView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .lineLimit(4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.thinMaterial, in: .rect(cornerRadius: 8))
            .accessibilityLabel("Selected text")
    }
}
