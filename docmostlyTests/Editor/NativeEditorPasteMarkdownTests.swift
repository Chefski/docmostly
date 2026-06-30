import Foundation
import SwiftUI
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

    @Test func pasteMarkdownURLOverSelectedTextAppliesLinkMarkLikeDocmostWeb() throws {
        let text = AttributedString("Review the spec")
        let range = try #require(text.range(of: "spec"))
        let block = NativeEditorBlock(
            kind: .paragraph,
            text: text,
            alignment: .left,
            selection: AttributedTextSelection(range: range)
        )
        let viewModel = configuredViewModel(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.pasteMarkdown("https://example.com/spec")

        #expect(viewModel.document.blocks.count == 1)
        #expect(String(viewModel.document.blocks[0].text.characters) == "Review the spec")
        #expect(viewModel.markdownForDocument() == "Review the [spec](https://example.com/spec)")

        let inlineNodes = try #require(viewModel.document.proseMirrorDocument.content.first?.content)
        #expect(inlineNodes.map(\.text) == ["Review the ", "spec"])
        #expect(
            inlineNodes[1].marks?.contains(
                ProseMirrorMark(type: "link", attrs: ["href": .string("https://example.com/spec")])
            ) == true
        )
    }

    @Test func pasteMarkdownProtocolLessURLOverSelectedTextAppliesDefaultProtocolLikeDocmostWeb() throws {
        let text = AttributedString("Review the spec")
        let range = try #require(text.range(of: "spec"))
        let block = NativeEditorBlock(
            kind: .paragraph,
            text: text,
            alignment: .left,
            selection: AttributedTextSelection(range: range)
        )
        let viewModel = configuredViewModel(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.pasteMarkdown("www.example.com/spec")

        #expect(viewModel.document.blocks.count == 1)
        #expect(String(viewModel.document.blocks[0].text.characters) == "Review the spec")
        #expect(viewModel.markdownForDocument() == "Review the [spec](http://www.example.com/spec)")

        let inlineNodes = try #require(viewModel.document.proseMirrorDocument.content.first?.content)
        #expect(inlineNodes.map(\.text) == ["Review the ", "spec"])
        #expect(
            inlineNodes[1].marks?.contains(
                ProseMirrorMark(type: "link", attrs: ["href": .string("http://www.example.com/spec")])
            ) == true
        )
    }

    private func configuredViewModel(blocks: [NativeEditorBlock]) -> NativeRichEditorViewModel {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: blocks)
        viewModel.resetEditingHistory()
        return viewModel
    }
}
