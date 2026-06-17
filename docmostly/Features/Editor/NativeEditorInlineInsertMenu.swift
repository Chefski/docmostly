import SwiftUI

struct NativeEditorInlineInsertMenu: View {
    @Binding var isShowingStatusPrompt: Bool
    @Binding var isShowingCommentPrompt: Bool
    @Binding var isShowingMathPrompt: Bool
    let showMentionPicker: () -> Void

    var body: some View {
        Menu {
            Button("Status", systemImage: "tag") {
                isShowingStatusPrompt = true
            }
            Button("Mention", systemImage: "at") {
                showMentionPicker()
            }
            Button("Comment", systemImage: "text.bubble") {
                isShowingCommentPrompt = true
            }
            Button("Math", systemImage: "function") {
                isShowingMathPrompt = true
            }
        } label: {
            Label("Insert Inline", systemImage: "plus.bubble")
        }
        .accessibilityLabel("Insert Inline")
    }
}
