import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeEditorInlineMarkdownExportTests {
    @Test func documentMarkdownConversionPreservesCommonInlineMarks() throws {
        var text = AttributedString("Use ")
        var bold = AttributedString("bold")
        bold.inlinePresentationIntent = .stronglyEmphasized
        var italic = AttributedString("italic")
        italic.inlinePresentationIntent = .emphasized
        var code = AttributedString("code")
        code.inlinePresentationIntent = .code
        var link = AttributedString("link")
        link.link = try #require(URL(string: "https://example.com/spec"))

        text += bold
        text += AttributedString(", ")
        text += italic
        text += AttributedString(", ")
        text += code
        text += AttributedString(", and ")
        text += link

        let block = NativeEditorBlock(kind: .paragraph, text: text, alignment: .left)
        let viewModel = configuredViewModel(blocks: [block])

        #expect(
            viewModel.markdownForDocument() ==
                "Use **bold**, *italic*, `code`, and [link](https://example.com/spec)"
        )
    }

    @Test func documentMarkdownConversionPreservesStrikethroughInlineMark() {
        var text = AttributedString("Archive ")
        var removed = AttributedString("old plan")
        removed.inlinePresentationIntent = .strikethrough
        text += removed

        let block = NativeEditorBlock(kind: .paragraph, text: text, alignment: .left)
        let viewModel = configuredViewModel(blocks: [block])

        #expect(viewModel.markdownForDocument() == "Archive ~~old plan~~")
    }

    private func configuredViewModel(blocks: [NativeEditorBlock]) -> NativeRichEditorViewModel {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: blocks)
        viewModel.resetEditingHistory()
        return viewModel
    }
}
