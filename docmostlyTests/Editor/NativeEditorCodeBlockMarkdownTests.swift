import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorCodeBlockMarkdownTests {
    @Test func codeBlockInputRuleUsesWholeOpeningFenceForLanguage() throws {
        let rule = try #require(NativeEditorMarkdownParser.inputRule(from: "````swift"))

        #expect(rule.kind == .codeBlock(language: "swift"))
        #expect(rule.text.isEmpty)
    }

    @Test func codeBlockMarkdownExportUsesLongerFenceWhenBodyContainsBacktickFence() throws {
        let code = """
        ```swift
        let value = true
        ```
        """
        let block = NativeEditorBlock(
            kind: .codeBlock(language: "markdown"),
            text: AttributedString(code),
            alignment: .left
        )

        let markdown = NativeEditorMarkdownParser.markdown(from: [block])

        #expect(markdown == """
        ````markdown
        ```swift
        let value = true
        ```
        ````
        """)

        let importedBlock = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)
        guard case .codeBlock(let language) = importedBlock.kind else {
            Issue.record("Expected Markdown to reimport as a code block.")
            return
        }

        #expect(language == "markdown")
        #expect(String(importedBlock.text.characters) == code)
    }
}
