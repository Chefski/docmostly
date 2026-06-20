import SwiftUI

struct NativeEditorInlineCommentComposerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    let selectedText: String
    let submit: (String) async throws -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                NativeEditorInlineCommentSelectionView(text: selectedText)

                TextEditor(text: $draft)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 132)
                    .padding(10)
                    .background(.background, in: .rect(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.quaternary)
                    }
                    .accessibilityLabel("Comment")

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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: dismiss.callAsFunction)
                        .disabled(isSubmitting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Add", systemImage: "checkmark", action: addComment)
                        .disabled(isSubmitting || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func addComment() {
        let commentText = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard commentText.isEmpty == false else { return }

        Task {
            isSubmitting = true
            errorMessage = nil
            defer { isSubmitting = false }

            do {
                try await submit(commentText)
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
