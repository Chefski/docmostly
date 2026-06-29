import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorBlockquoteMarkdownTests {
    @Test func blockquoteMarkdownExportPrefixesEveryLine() throws {
        let block = NativeEditorBlock(
            kind: .blockquote,
            text: AttributedString("Quote line one\nQuote line two"),
            alignment: .left
        )

        let markdown = NativeEditorMarkdownParser.markdown(from: [block])

        #expect(markdown == """
        > Quote line one
        > Quote line two
        """)

        let importedBlock = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)
        #expect(importedBlock.kind == .blockquote)
        #expect(String(importedBlock.text.characters) == "Quote line one\nQuote line two")
    }
}
