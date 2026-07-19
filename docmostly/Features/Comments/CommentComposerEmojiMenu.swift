import SwiftUI

struct CommentComposerEmojiMenu: View {
    let draft: CommentComposerState
    let isEnabled: Bool

    var body: some View {
        Menu("Insert Emoji", systemImage: "face.smiling") {
            ForEach(CommentEmoji.all) { emoji in
                Button("\(emoji.symbol)  \(emoji.name.capitalized)") {
                    draft.insertEmoji(emoji)
                }
            }
        }
        .labelStyle(.iconOnly)
        .menuStyle(.button)
        .disabled(isEnabled == false)
        .help("Insert Emoji")
    }
}
