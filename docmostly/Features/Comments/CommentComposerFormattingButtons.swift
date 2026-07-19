import SwiftUI

struct CommentComposerFormattingButtons: View {
    let draft: CommentComposerState
    let isEnabled: Bool

    var body: some View {
        ForEach(CommentComposerFormat.allCases) { format in
            Button(format.title, systemImage: format.systemImage) {
                draft.toggle(format)
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(draft.isActive(format) ? DocmostlyTheme.primary : .secondary)
            .disabled(draft.hasSelection == false || isEnabled == false)
            .help(format.title)
        }
    }
}
