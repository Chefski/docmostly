import SwiftUI

#if DEBUG
struct NativeEditorDebugPreviewView: View {
    @State private var viewModel = NativeRichEditorViewModel(pageID: "preview", initialTitle: "Blah blah")
    @FocusState private var focusedField: NativeEditorFocus?

    var body: some View {
        NavigationStack {
            ScrollView {
                NativeEditorBodyView(viewModel: viewModel, focusedField: $focusedField)
                    .padding()
                    .frame(maxWidth: 900, alignment: .leading)
            }
                .navigationTitle("Inline Editor")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.isEditing {
                NativeEditorToolbar(viewModel: viewModel) {
                    focusedField = nil
                    viewModel.clearFocus()
                }
            }
        }
        .onAppear(perform: configurePreview)
        .onChange(of: focusedField) { _, newValue in
            updateFocus(newValue)
        }
        .onChange(of: viewModel.title) {
            viewModel.handleTitleChanged()
        }
    }

    private func configurePreview() {
        guard viewModel.document.blocks.first?.text.characters.isEmpty == true else { return }

        viewModel.document = NativeEditorDocument(blocks: Self.previewBlocks)
        viewModel.resetEditingHistory()
    }

    private func updateFocus(_ focus: NativeEditorFocus?) {
        switch focus {
        case .title:
            viewModel.focusTitle()
        case .block(let blockID):
            viewModel.focus(blockID: blockID)
        case nil:
            guard viewModel.isTitleFocused else { return }
            viewModel.clearFocus()
        }
    }

    private static let previewBlocks = [
        NativeEditorBlock(
            kind: .paragraph,
            text: AttributedString("The quick brown fox jumped over the fence or whatever"),
            alignment: .left
        ),
        NativeEditorBlock(kind: .heading(level: 1), text: AttributedString("Heading 1"), alignment: .left),
        NativeEditorBlock(kind: .heading(level: 2), text: AttributedString("Heading 2"), alignment: .left),
        NativeEditorBlock(kind: .heading(level: 3), text: AttributedString("Heading 3"), alignment: .left),
        NativeEditorBlock(
            kind: .bulletListItem,
            text: AttributedString("Bullet 1"),
            alignment: .left
        ),
        NativeEditorBlock(
            kind: .bulletListItem,
            text: AttributedString("Bullet 1"),
            alignment: .left
        ),
        NativeEditorBlock(kind: .bulletListItem, text: AttributedString("Bullet 3"), alignment: .left),
        NativeEditorBlock(
            kind: .orderedListItem(ordinal: 1),
            text: AttributedString("One"),
            alignment: .left
        ),
        NativeEditorBlock(
            kind: .orderedListItem(ordinal: 2),
            text: AttributedString("Two"),
            alignment: .left
        ),
        NativeEditorBlock(
            kind: .orderedListItem(ordinal: 3),
            text: AttributedString("Three"),
            alignment: .left
        ),
        NativeEditorBlock(
            kind: .taskListItem(isChecked: false),
            text: AttributedString("Todo 1"),
            alignment: .left
        ),
        NativeEditorBlock(
            kind: .taskListItem(isChecked: false),
            text: AttributedString("Todo 2"),
            alignment: .left
        ),
        NativeEditorBlock(kind: .blockquote, text: AttributedString("The quick maniac man"), alignment: .left),
        NativeEditorBlock(kind: .divider, text: AttributedString("Divider"), alignment: .left),
        NativeEditorBlock(
            kind: .codeBlock(language: "swift"),
            text: AttributedString(#"print("Hello World!")"#),
            alignment: .left
        ),
        NativeEditorBlock(
            kind: .details(NativeEditorDetailsBlock(
                summary: "Toggle block",
                previewText: "Can you see everything here?",
                isOpen: false
            )),
            text: AttributedString("Toggle block"),
            alignment: .left
        ),
        NativeEditorBlock(
            kind: .details(NativeEditorDetailsBlock(
                summary: "Open toggle block",
                previewText: "Can you see everything here?",
                isOpen: true
            )),
            text: AttributedString("Open toggle block"),
            alignment: .left
        ),
        NativeEditorBlock(
            kind: .callout(NativeEditorCalloutBlock(
                style: "danger",
                icon: nil,
                previewText: "Hey you better watch out!!!!"
            )),
            text: AttributedString("Hey you better watch out!!!!"),
            alignment: .left
        )
    ]
}
#endif
