import SwiftUI

struct CommentRichComposerView: View {
    @Bindable var draft: CommentComposerState
    @FocusState private var isFocused: Bool
    @State private var isShowingLinkEditor = false
    @State private var isShowingMentionPicker = false

    let placeholder: String
    let submitTitle: String
    let accessibilityIdentifier: String
    let isEnabled: Bool
    let isSubmitting: Bool
    let autofocus: Bool
    let submit: () -> Void
    var cancel: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                if draft.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 8)
                        .accessibilityHidden(true)
                }

                TextEditor(text: $draft.text, selection: $draft.selection)
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .focused($isFocused)
                    .frame(minHeight: 72, maxHeight: 180)
                    .accessibilityLabel(placeholder)
                    .accessibilityIdentifier(accessibilityIdentifier)
            }
            .padding(4)
            .background(.quaternary.opacity(0.35), in: .rect(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isFocused ?
                            AnyShapeStyle(DocmostlyTheme.primary.opacity(0.55)) : AnyShapeStyle(.quaternary)
                    )
            }

            if let mentionQuery = draft.activeQuery(after: "@"), mentionQuery.isEmpty == false {
                CommentMentionSuggestionsView(query: mentionQuery, draft: draft)
            } else if let emojiQuery = draft.activeQuery(after: ":") {
                CommentEmojiSuggestionsView(query: emojiQuery, draft: draft)
            }

            CommentComposerToolbarView(
                draft: draft,
                submitTitle: submitTitle,
                isEnabled: isEnabled,
                isSubmitting: isSubmitting,
                showLinkEditor: {
                    isShowingLinkEditor = true
                },
                showMentionPicker: {
                    isShowingMentionPicker = true
                },
                submit: submit,
                cancel: cancel
            )
        }
        .disabled(isEnabled == false)
        .popover(isPresented: $isShowingLinkEditor) {
            CommentLinkEditorView(draft: draft)
                .presentationCompactAdaptation(.sheet)
        }
        .popover(isPresented: $isShowingMentionPicker) {
            CommentMentionPickerView(draft: draft)
                .presentationCompactAdaptation(.sheet)
        }
        .onAppear {
            if autofocus {
                isFocused = true
            }
        }
    }
}

private struct CommentEmojiSuggestionsView: View {
    let query: String
    let draft: CommentComposerState

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                ForEach(CommentEmoji.suggestions(matching: query).prefix(5)) { emoji in
                    Button("\(emoji.symbol) \(emoji.name.capitalized)") {
                        draft.insertEmoji(emoji)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityLabel("Emoji suggestions")
    }
}
