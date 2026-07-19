import SwiftUI

struct CommentComposerToolbarView: View {
    @Bindable var draft: CommentComposerState

    let submitTitle: String
    let isEnabled: Bool
    let isSubmitting: Bool
    let showLinkEditor: () -> Void
    let showMentionPicker: () -> Void
    let submit: () -> Void
    let cancel: (() -> Void)?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack {
                CommentComposerFormattingButtons(draft: draft, isEnabled: isEnabled)

                Button("Add Link", systemImage: "link", action: showLinkEditor)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .disabled(draft.hasSelection == false || isEnabled == false)
                    .help("Add Link")

                Button("Mention Person", systemImage: "at", action: showMentionPicker)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .disabled(isEnabled == false)
                    .help("Mention Person")

                CommentComposerEmojiMenu(draft: draft, isEnabled: isEnabled)

                Spacer(minLength: 0)

                CommentComposerSubmissionControls(
                    draft: draft,
                    submitTitle: submitTitle,
                    isEnabled: isEnabled,
                    isSubmitting: isSubmitting,
                    submit: submit,
                    cancel: cancel
                )
            }

            HStack {
                Menu("Comment Tools", systemImage: "textformat") {
                    Section("Formatting") {
                        ForEach(CommentComposerFormat.allCases) { format in
                            Button(
                                format.title,
                                systemImage: draft.isActive(format) ? "checkmark" : format.systemImage
                            ) {
                                draft.toggle(format)
                            }
                            .disabled(draft.hasSelection == false)
                        }
                    }

                    Button("Add Link", systemImage: "link", action: showLinkEditor)
                        .disabled(draft.hasSelection == false)
                    Button("Mention Person", systemImage: "at", action: showMentionPicker)

                    Menu("Insert Emoji", systemImage: "face.smiling") {
                        ForEach(CommentEmoji.all) { emoji in
                            Button("\(emoji.symbol)  \(emoji.name.capitalized)") {
                                draft.insertEmoji(emoji)
                            }
                        }
                    }
                }
                .disabled(isEnabled == false)

                Spacer(minLength: 0)

                CommentComposerSubmissionControls(
                    draft: draft,
                    submitTitle: submitTitle,
                    isEnabled: isEnabled,
                    isSubmitting: isSubmitting,
                    submit: submit,
                    cancel: cancel
                )
            }
        }
    }
}
