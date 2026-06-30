import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorPasteMarkdownTests {
    @Test func pasteMarkdownReplacesSingleEmptyPlaceholderBlock() {
        let block = NativeEditorDocument.emptyBlock()
        let viewModel = configuredViewModel(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.pasteMarkdown("""
        # Roadmap
        - Native paste
        """)

        #expect(viewModel.document.blocks.map(\.kind) == [
            .heading(level: 1),
            .bulletListItem
        ])
        #expect(String(viewModel.document.blocks[0].text.characters) == "Roadmap")
        #expect(String(viewModel.document.blocks[1].text.characters) == "Native paste")
        #expect(viewModel.activeBlockID == viewModel.document.blocks[1].id)
    }

    private func configuredViewModel(blocks: [NativeEditorBlock]) -> NativeRichEditorViewModel {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: blocks)
        viewModel.resetEditingHistory()
        return viewModel
    }
}
