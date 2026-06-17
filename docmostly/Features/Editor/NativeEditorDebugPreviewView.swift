import SwiftUI

#if DEBUG
struct NativeEditorDebugPreviewView: View {
    @State private var viewModel = NativeRichEditorViewModel(pageID: "preview", initialTitle: "Native Editor")
    @FocusState private var focusedField: NativeEditorFocus?

    var body: some View {
        NavigationStack {
            ScrollView {
                NativeEditorBodyView(viewModel: viewModel, focusedField: $focusedField)
                    .padding()
                    .frame(maxWidth: 900, alignment: .leading)
            }
                .navigationTitle("Inline Editor")
                .navigationBarTitleDisplayMode(.inline)
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
        .onChange(of: viewModel.document) {
            viewModel.recalculateDirty()
        }
        .onChange(of: viewModel.title) {
            viewModel.recalculateDirty()
        }
    }

    private func configurePreview() {
        guard viewModel.document.blocks.first?.text.characters.isEmpty == true else { return }

        var paragraph = AttributedString(
            "Select text, then use the toolbar for bold, italic, lists, links, and alignment."
        )
        paragraph.inlinePresentationIntent = .emphasized

        viewModel.document = NativeEditorDocument(blocks: [
            NativeEditorBlock(
                kind: .heading(level: 1),
                text: AttributedString("Native Docmost editor"),
                alignment: .left
            ),
            NativeEditorBlock(kind: .paragraph, text: paragraph, alignment: .left),
            NativeEditorBlock(
                kind: .bulletListItem,
                text: AttributedString("ProseMirror JSON bridge"),
                alignment: .left
            ),
            NativeEditorBlock(
                kind: .bulletListItem,
                text: AttributedString("Keyboard toolbar"),
                alignment: .left
            ),
            NativeEditorBlock(
                kind: .taskListItem(isChecked: false),
                text: AttributedString("Autosave through pages/update"),
                alignment: .left
            ),
            NativeEditorBlock(
                kind: .paragraph,
                text: AttributedString("/to"),
                alignment: .left
            )
        ])
        if let commandBlockID = viewModel.document.blocks.last?.id {
            viewModel.focus(blockID: commandBlockID)
            focusedField = .block(commandBlockID)
        }
        viewModel.recalculateDirty()
    }

    private func updateFocus(_ focus: NativeEditorFocus?) {
        switch focus {
        case .title:
            viewModel.focusTitle()
        case .block(let blockID):
            viewModel.focus(blockID: blockID)
        case nil:
            viewModel.clearFocus()
        }
    }
}
#endif
