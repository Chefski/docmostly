import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorMathMarkdownTests {
    @Test func markdownImportKeepsCurrencyDollarAmountsAsPlainText() throws {
        let block = try #require(NativeEditorMarkdownParser.blocks(
            from: "Budget is $5 and $6 tomorrow"
        ).first)

        #expect(String(block.text.characters) == "Budget is $5 and $6 tomorrow")
        #expect(block.text.runs.contains { run in
            run[NativeEditorMathInlineAttribute.self] != nil
        } == false)

        let inlineNodes = try #require(NativeEditorDocument.node(from: block).content)
        #expect(inlineNodes.map(\.type) == ["text"])
        #expect(inlineNodes.first?.text == "Budget is $5 and $6 tomorrow")
    }
}
