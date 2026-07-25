import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorFrontMatterImportTests {
    @Test func markdownImportDropsLeadingYAMLFrontMatter() throws {
        let blocks = NativeEditorMarkdownParser.blocks(from: """
        ---
        title: Launch plan
        tags:
          - rollout
        ---

        # Overview
        Ready to ship
        """)

        #expect(blocks.count == 2)
        let heading = try #require(blocks.first)
        let paragraph = try #require(blocks.last)
        #expect(heading.kind == .heading(level: 1))
        #expect(String(heading.text.characters) == "Overview")
        #expect(paragraph.kind == .paragraph)
        #expect(String(paragraph.text.characters) == "Ready to ship")
    }

    @Test func frontMatterDelimiterMustBeOnItsOwnLine() throws {
        let block = try #require(NativeEditorMarkdownParser.blocks(from: """
        ---
        title: Launch --- plan
        summary: Keep parsing metadata
        ---

        Ready to ship
        """).first)

        #expect(block.kind == .paragraph)
        #expect(String(block.text.characters) == "Ready to ship")
    }
}
