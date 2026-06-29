import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorTableMarkdownImportTests {
    @Test func markdownTableImportPreservesPipesInsideCodeSpans() throws {
        let blocks = NativeEditorMarkdownParser.blocks(from: """
        | Expression | Result |
        | --- | --- |
        | `a | b` | Ready |
        """)

        let block = try #require(blocks.first)
        guard case .table(let table) = block.kind else {
            Issue.record("Expected markdown table")
            return
        }

        #expect(table.rows.count == 2)
        #expect(table.rows[1].cells[0].plainText == "a | b")
        #expect(table.rows[1].cells[1].plainText == "Ready")
        #expect(table.rows[1].cells[0].inlineContent == [
            .text("a | b", marks: [.code])
        ])
    }
}
