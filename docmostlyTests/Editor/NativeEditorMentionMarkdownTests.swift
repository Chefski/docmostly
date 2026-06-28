import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeEditorMentionMarkdownTests {
    @Test func pasteMarkdownDocmostPageLinksCreatesMentionAtoms() throws {
        let intro = NativeEditorBlock(kind: .paragraph, text: AttributedString("Intro"), alignment: .left)
        let viewModel = configuredViewModel(blocks: [intro])
        viewModel.focus(blockID: intro.id)

        viewModel.pasteMarkdown(
            "Discuss [Roadmap](https://docs.example.com/s/product/p/native-roadmap-abc123#shipping) today"
        )

        let inlineNodes = viewModel.document.proseMirrorDocument.content.last?.content ?? []
        #expect(inlineNodes.map(\.type) == ["text", "mention", "text"])
        #expect(inlineNodes[0].text == "Discuss ")
        #expect(inlineNodes[2].text == " today")

        let attrs = try #require(inlineNodes[1].attrs)
        #expect(attrs["label"] == .string("Roadmap"))
        #expect(attrs["entityType"] == .string("page"))
        #expect(attrs["entityId"] == .string("abc123"))
        #expect(attrs["slugId"] == .string("abc123"))
        #expect(attrs["anchorId"] == .string("shipping"))
        #expect(attrs["id"]?.stringValue?.isEmpty == false)
    }

    @Test func pasteMarkdownBareDocmostPageURLCreatesMentionAtom() throws {
        let intro = NativeEditorBlock(kind: .paragraph, text: AttributedString("Intro"), alignment: .left)
        let viewModel = configuredViewModel(blocks: [intro])
        viewModel.focus(blockID: intro.id)

        viewModel.pasteMarkdown("https://docs.example.com/s/product/p/native-roadmap-abc123#shipping")

        let inlineNodes = viewModel.document.proseMirrorDocument.content.last?.content ?? []
        #expect(inlineNodes.map(\.type) == ["mention"])

        let attrs = try #require(inlineNodes[0].attrs)
        #expect(attrs["label"] == .string("native-roadmap"))
        #expect(attrs["entityType"] == .string("page"))
        #expect(attrs["entityId"] == .string("abc123"))
        #expect(attrs["slugId"] == .string("abc123"))
        #expect(attrs["anchorId"] == .string("shipping"))
    }

    @Test func documentMarkdownConversionPreservesMentionAtomsAsDocmostLinks() {
        var text = AttributedString("Discuss ")
        var mentionText = AttributedString("Roadmap")
        mentionText[NativeEditorMentionAttribute.self] = NativeEditorMention(
            identifier: "mention-1",
            label: "Roadmap",
            entityType: "page",
            entityID: "page-1",
            slugID: "abc123",
            anchorID: "shipping"
        )
        text += mentionText
        text += AttributedString(" today")

        let block = NativeEditorBlock(kind: .paragraph, text: text, alignment: .left)
        let viewModel = configuredViewModel(blocks: [block])

        #expect(viewModel.markdownForDocument() == "Discuss [Roadmap](/p/abc123#shipping) today")
    }

    private func configuredViewModel(blocks: [NativeEditorBlock]) -> NativeRichEditorViewModel {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: blocks)
        viewModel.resetEditingHistory()
        return viewModel
    }
}
