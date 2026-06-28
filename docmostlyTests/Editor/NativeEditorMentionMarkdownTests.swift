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

    @Test func pasteMarkdownPageMentionsPreservesSurroundingInlineMarks() {
        let intro = NativeEditorBlock(kind: .paragraph, text: AttributedString("Intro"), alignment: .left)
        let viewModel = configuredViewModel(blocks: [intro])
        viewModel.focus(blockID: intro.id)

        viewModel.pasteMarkdown(
            """
            Discuss **urgent** [spec](https://example.com/spec) before \
            [Roadmap](https://docs.example.com/s/product/p/native-roadmap-abc123) now
            """
        )

        let inlineNodes = viewModel.document.proseMirrorDocument.content.last?.content ?? []
        #expect(inlineNodes.map(\.type) == ["text", "text", "text", "text", "text", "mention", "text"])
        #expect(inlineNodes[1].text == "urgent")
        #expect(inlineNodes[1].marks?.contains(ProseMirrorMark(type: "bold")) == true)
        #expect(inlineNodes[3].text == "spec")
        #expect(
            inlineNodes[3].marks?.contains(
                ProseMirrorMark(type: "link", attrs: ["href": .string("https://example.com/spec")])
            ) == true
        )
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

    @Test func documentMarkdownConversionPreservesUserMentionAtomsAsDocmostHTML() {
        var text = AttributedString("Discuss ")
        var mentionText = AttributedString("@Taylor")
        mentionText[NativeEditorMentionAttribute.self] = NativeEditorMention(
            identifier: "mention-1",
            label: "Taylor",
            entityType: "user",
            entityID: "user-1",
            creatorID: "creator-1"
        )
        text += mentionText
        text += AttributedString(" today")

        let block = NativeEditorBlock(kind: .paragraph, text: text, alignment: .left)
        let viewModel = configuredViewModel(blocks: [block])
        let mentionHTML = userMentionHTML()

        #expect(viewModel.markdownForDocument() == "Discuss \(mentionHTML) today")
    }

    @Test func pasteMarkdownDocmostUserMentionHTMLCreatesMentionAtom() throws {
        let intro = NativeEditorBlock(kind: .paragraph, text: AttributedString("Intro"), alignment: .left)
        let viewModel = configuredViewModel(blocks: [intro])
        viewModel.focus(blockID: intro.id)
        let mentionHTML = userMentionHTML()

        viewModel.pasteMarkdown("Discuss \(mentionHTML) today")

        let inlineNodes = viewModel.document.proseMirrorDocument.content.last?.content ?? []
        #expect(inlineNodes.map(\.type) == ["text", "mention", "text"])
        #expect(inlineNodes[0].text == "Discuss ")
        #expect(inlineNodes[2].text == " today")

        let attrs = try #require(inlineNodes[1].attrs)
        #expect(attrs["id"] == .string("mention-1"))
        #expect(attrs["label"] == .string("Taylor"))
        #expect(attrs["entityType"] == .string("user"))
        #expect(attrs["entityId"] == .string("user-1"))
        #expect(attrs["creatorId"] == .string("creator-1"))
    }

    @Test func pasteMarkdownDocmostUserMentionHTMLAllowsLiteralSpanTextBeforeClosingSpan() throws {
        let intro = NativeEditorBlock(kind: .paragraph, text: AttributedString("Intro"), alignment: .left)
        let viewModel = configuredViewModel(blocks: [intro])
        viewModel.focus(blockID: intro.id)
        let mentionHTML = #"<span data-type="mention" data-id="mention-1" data-label="Taylor" "# +
            #"data-entity-type="user" data-entity-id="user-1">"# +
            "@Taylor `<span>`</span>"

        viewModel.pasteMarkdown("Discuss \(mentionHTML) today")

        let inlineNodes = viewModel.document.proseMirrorDocument.content.last?.content ?? []
        #expect(inlineNodes.map(\.type) == ["text", "mention", "text"])
        #expect(inlineNodes[0].text == "Discuss ")
        #expect(inlineNodes[2].text == " today")

        let attrs = try #require(inlineNodes[1].attrs)
        #expect(attrs["id"] == .string("mention-1"))
        #expect(attrs["label"] == .string("Taylor"))
        #expect(attrs["entityType"] == .string("user"))
        #expect(attrs["entityId"] == .string("user-1"))
    }

    private func userMentionHTML() -> String {
        #"<span data-type="mention" data-id="mention-1" data-label="Taylor" "# +
            #"data-entity-type="user" data-entity-id="user-1" data-creator-id="creator-1">"# +
            "@Taylor</span>"
    }

    private func configuredViewModel(blocks: [NativeEditorBlock]) -> NativeRichEditorViewModel {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: blocks)
        viewModel.resetEditingHistory()
        return viewModel
    }
}
