import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeEditorInlineMarkdownShortcutTests {
    @Test func markdownInputRuleSupportsDocmostUnderscoreMarkShortcuts() throws {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString(""), alignment: .left)
        let viewModel = configuredViewModel(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.document.blocks[0].text = AttributedString("Use __strong__ and _emphasis_")
        viewModel.handleDocumentChanged()

        #expect(String(viewModel.document.blocks[0].text.characters) == "Use strong and emphasis")

        let inlineNodes = try #require(viewModel.document.proseMirrorDocument.content.first?.content)
        #expect(inlineNodes.contains {
            $0.text == "strong" && $0.marks?.contains(ProseMirrorMark(type: "bold")) == true
        })
        #expect(inlineNodes.contains {
            $0.text == "emphasis" && $0.marks?.contains(ProseMirrorMark(type: "italic")) == true
        })

        viewModel.undo()

        #expect(String(viewModel.document.blocks[0].text.characters).isEmpty)
    }

    private func configuredViewModel(blocks: [NativeEditorBlock]) -> NativeRichEditorViewModel {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: blocks)
        viewModel.resetEditingHistory()
        return viewModel
    }
}
