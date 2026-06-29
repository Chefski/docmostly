import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorMathMarkdownTests {
    @Test func nativeMathBlockExportsAsDocmostMathFenceMarkdown() {
        let block = NativeEditorBlock(
            kind: .mathBlock(NativeEditorMathBlock(text: "E = mc^2")),
            text: AttributedString("E = mc^2"),
            alignment: .left
        )

        #expect(NativeEditorMarkdownParser.markdown(from: [block]) == """
        $$
        E = mc^2
        $$
        """)
    }

    @Test func markdownImportSupportsSingleLineMathBlockFence() throws {
        let block = try #require(NativeEditorMarkdownParser.blocks(
            from: "$$E = mc^2$$"
        ).first)

        guard case .mathBlock(let math) = block.kind else {
            Issue.record("Expected standalone double-dollar math to import as a native math block.")
            return
        }

        #expect(math.text == "E = mc^2")
        #expect(block.rawNode?.type == "mathBlock")
        #expect(block.rawNode?.attrs?["text"] == .string("E = mc^2"))
        #expect(NativeEditorMarkdownParser.markdown(from: [block]) == """
        $$
        E = mc^2
        $$
        """)
    }

    @Test func markdownImportKeepsCurrencyDollarAmountsAsPlainText() throws {
        let block = try #require(NativeEditorMarkdownParser.blocks(
            from: "Budget is $5 and $6 tomorrow"
        ).first)

        #expect(String(block.text.characters) == "Budget is $5 and $6 tomorrow")
        #expect(block.text.runs.contains { run in
            run[NativeEditorMathInlineAttribute.self] != nil
        } == false)

        let inlineNodes = try #require(NativeEditorDocument.node(from: block).content)
        #expect(inlineNodes.contains { node in node.type == "mathInline" } == false)
        #expect(inlineNodes.compactMap(\.text).joined() == "Budget is $5 and $6 tomorrow")
    }

    @Test func markdownImportKeepsMathDelimitersInsideCodeSpansAsCodeText() throws {
        let block = try #require(NativeEditorMarkdownParser.blocks(
            from: "Use `$value$` and $$total$$"
        ).first)

        let codeRun = try #require(block.text.runs.first { run in
            String(block.text[run.range].characters) == "$value$"
        })
        #expect(codeRun.inlinePresentationIntent?.contains(.code) == true)
        #expect(codeRun[NativeEditorMathInlineAttribute.self] == nil)

        let mathRun = try #require(block.text.runs.first { run in
            run[NativeEditorMathInlineAttribute.self]?.text == "total"
        })
        #expect(String(block.text[mathRun.range].characters) == "total")
    }
}
