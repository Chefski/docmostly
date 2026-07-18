import SwiftUI

struct CommentComposerSubmissionControls: View {
    let draft: CommentComposerState
    let submitTitle: String
    let isEnabled: Bool
    let isSubmitting: Bool
    let submit: () -> Void
    let cancel: (() -> Void)?

    var body: some View {
        if let cancel {
            Button("Cancel", action: cancel)
                .controlSize(.small)
                .keyboardShortcut(.cancelAction)
        }

        if isSubmitting {
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("Posting comment")
        }

        Button(submitTitle, systemImage: "arrow.up", action: submit)
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(isEnabled == false || isSubmitting || draft.isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
    }
}
