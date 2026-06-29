import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeEditorDividerMarkdownTests {
    @Test func markdownImportSupportsUnderscoreDivider() throws {
        let block = try #require(NativeEditorMarkdownParser.blocks(from: "___").first)

        #expect(block.kind == .divider)
        #expect(String(block.text.characters) == "Divider")
    }

    @Test func markdownInputRuleSupportsUnderscoreDividerShortcut() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString(""), alignment: .left)
        let viewModel = configuredViewModel(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.document.blocks[0].text = AttributedString("___")
        viewModel.handleDocumentChanged()

        #expect(viewModel.document.blocks[0].kind == .divider)
        #expect(String(viewModel.document.blocks[0].text.characters) == "Divider")
        #expect(viewModel.markdownForDocument() == "---")
    }

    private func configuredViewModel(blocks: [NativeEditorBlock]) -> NativeRichEditorViewModel {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: blocks)
        viewModel.resetEditingHistory()
        return viewModel
    }
}
