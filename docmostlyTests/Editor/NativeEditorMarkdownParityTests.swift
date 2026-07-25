import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorMarkdownParityTests {
    @Test func setextHeadingsPreserveInlineFormatting() throws {
        let blocks = NativeEditorMarkdownParser.blocks(from: """
        **Overview**
        ===
        Release notes
        ---
        """)

        try #require(blocks.count == 2)
        #expect(blocks.map(\.kind) == [.heading(level: 1), .heading(level: 2)])
        #expect(String(blocks[0].text.characters) == "Overview")
        #expect(blocks[0].text.runs.first?.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
        #expect(String(blocks[1].text.characters) == "Release notes")
    }

    @Test func indentedCodeBlocksPreserveBlankLinesAndIndentation() throws {
        let blocks = NativeEditorMarkdownParser.blocks(from: """
            let value = 1

                print(value)
        Paragraph
        """)

        try #require(blocks.count == 2)
        guard case .codeBlock(language: nil) = blocks[0].kind else {
            Issue.record("Expected a language-neutral indented code block.")
            return
        }
        #expect(String(blocks[0].text.characters) == "let value = 1\n\n    print(value)")
        #expect(blocks[1].kind == .paragraph)
        #expect(String(blocks[1].text.characters) == "Paragraph")
    }

    @Test func referenceStyleLinksAndImagesResolveCaseInsensitively() throws {
        let blocks = NativeEditorMarkdownParser.blocks(from: """
        Read the [Guide][DOCS].
        ![Architecture][asset]
        [Shortcut]

        [docs]: https://docs.example.com/guide
        [asset]: /files/architecture.png "System diagram"
        [shortcut]: https://example.com
        """)

        try #require(blocks.count == 3)
        let guideRun = try #require(blocks[0].text.runs.first { run in
            blocks[0].text[run.range].characters.elementsEqual("Guide")
        })
        #expect(linkDestination(in: guideRun) == "https://docs.example.com/guide")

        guard case .image(let image) = blocks[1].kind else {
            Issue.record("Expected a reference-style image to become a native image block.")
            return
        }
        #expect(image.source == "/files/architecture.png")
        #expect(image.title == "System diagram")

        let shortcutRun = try #require(blocks[2].text.runs.first)
        #expect(linkDestination(in: shortcutRun) == "https://example.com")
    }

    @Test func referenceDefinitionsSupportEscapedClosingBrackets() throws {
        let block = try #require(NativeEditorMarkdownParser.blocks(from: #"""
        [Guide][foo\]bar]

        [foo\]bar]: https://docs.example.com/guide
        """#).first)
        let linkRun = try #require(block.text.runs.first)

        #expect(String(block.text.characters) == "Guide")
        #expect(linkDestination(in: linkRun) == "https://docs.example.com/guide")
    }

    @Test func referenceSyntaxIsNotResolvedInsideIndentedCode() throws {
        let block = try #require(NativeEditorMarkdownParser.blocks(from: """
            [Guide][docs]

        [docs]: https://docs.example.com/guide
        """).first)

        guard case .codeBlock(language: nil) = block.kind else {
            Issue.record("Expected indented code.")
            return
        }
        #expect(String(block.text.characters) == "[Guide][docs]")
    }

    @Test func escapedReferenceOpeningRemainsLiteral() throws {
        let block = try #require(NativeEditorMarkdownParser.blocks(from: #"""
        \[Guide][docs]

        [docs]: https://docs.example.com/guide
        """#).first)

        #expect(String(block.text.characters) == "[Guide][docs]")
        #expect(block.text.runs.allSatisfy { linkDestination(in: $0) == nil })
    }

    @Test func inlineCodeLinkLabelsMayContainClosingBrackets() throws {
        let block = try #require(NativeEditorMarkdownParser.blocks(
            from: "[`value]`](https://docs.example.com/code)"
        ).first)
        let run = try #require(block.text.runs.first)

        #expect(String(block.text.characters) == "value]")
        #expect(run.inlinePresentationIntent?.contains(.code) == true)
        #expect(linkDestination(in: run) == "https://docs.example.com/code")
    }

    @Test func referenceDefinitionsDoNotRewriteFencedCode() throws {
        let block = try #require(NativeEditorMarkdownParser.blocks(from: """
        ```markdown
        [Guide][docs]
        ```
        [docs]: https://docs.example.com
        """).first)

        guard case .codeBlock(language: "markdown") = block.kind else {
            Issue.record("Expected fenced Markdown code.")
            return
        }
        #expect(String(block.text.characters) == "[Guide][docs]")
    }

    @Test(arguments: [
        "*literal emphasis*",
        "~~literal strike~~",
        "`literal code`",
        "# literal heading",
        "- literal list",
        "1. literal ordered list",
        "> literal quote",
        "```literal fence",
        "[label](not-a-link)",
        "![image](not-an-image.png)",
        "<span>literal HTML</span>",
        "---",
        "----",
        "====",
        #"path\name"#
    ])
    func literalMarkdownSyntaxRoundTripsAsParagraph(_ source: String) throws {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString(source), alignment: .left)
        let markdown = NativeEditorMarkdownParser.markdown(from: [block])
        let imported = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)

        #expect(imported.kind == .paragraph)
        #expect(String(imported.text.characters) == source)
    }

    private func linkDestination(in run: AttributedString.Runs.Run) -> String? {
        run[NativeEditorLinkAttribute.self]?.href ?? run.link?.absoluteString
    }
}
