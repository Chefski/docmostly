import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorHeadingMarkdownTests {
    @Test func markdownImportPreservesDeepHeadingLevels() throws {
        let markdown = """
        #### Deep section
        ##### Deep subsection
        ###### Deep detail
        """
        let blocks = NativeEditorMarkdownParser.blocks(from: markdown)

        try #require(blocks.count == 3)
        #expect(blocks[0].kind == .heading(level: 4))
        #expect(blocks[1].kind == .heading(level: 5))
        #expect(blocks[2].kind == .heading(level: 6))
        #expect(NativeEditorMarkdownParser.markdown(from: blocks) == markdown)
    }
}
