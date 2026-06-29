import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorMarkdownBalancedLinkTests {
    @Test func inlineMarkdownLinksImportDestinationsWithBalancedParentheses() throws {
        let source = "https://example.com/releases/Launch_(June)"
        let block = try #require(NativeEditorMarkdownParser.blocks(
            from: #"Stage <span data-type="status" data-color="green">Ship</span> [Launch notes](\#(source))"#
        ).first)

        #expect(block.kind == .paragraph)
        let statusRun = try #require(block.text.runs.first { run in
            run[NativeEditorStatusAttribute.self]?.text == "Ship"
        })
        #expect(statusRun[NativeEditorStatusAttribute.self]?.color == "green")

        let linkRun = try #require(block.text.runs.first { run in
            run.link?.absoluteString == source
        })
        #expect(String(block.text[linkRun.range].characters) == "Launch notes")
        #expect(String(block.text.characters) == "Stage Ship Launch notes")
    }
}
