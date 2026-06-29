import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorListMarkdownTests {
    @Test func bulletListMarkdownExportPrefixesContinuationLines() throws {
        let block = NativeEditorBlock(
            kind: .bulletListItem,
            text: AttributedString("First line\nSecond line"),
            alignment: .left
        )

        let markdown = NativeEditorMarkdownParser.markdown(from: [block])

        #expect(markdown == """
        - First line
          Second line
        """)

        let importedBlock = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)
        #expect(importedBlock.kind == .bulletListItem)
        #expect(String(importedBlock.text.characters) == "First line\nSecond line")
    }

    @Test func orderedListMarkdownExportPrefixesContinuationLines() throws {
        let block = NativeEditorBlock(
            kind: .orderedListItem(ordinal: 12),
            text: AttributedString("First line\nSecond line"),
            alignment: .left
        )

        let markdown = NativeEditorMarkdownParser.markdown(from: [block])

        #expect(markdown == """
        12. First line
            Second line
        """)

        let importedBlock = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)
        #expect(importedBlock.kind == .orderedListItem(ordinal: 12))
        #expect(String(importedBlock.text.characters) == "First line\nSecond line")
    }

    @Test func taskListMarkdownExportPrefixesContinuationLines() throws {
        let block = NativeEditorBlock(
            kind: .taskListItem(isChecked: false),
            text: AttributedString("First line\nSecond line"),
            alignment: .left
        )

        let markdown = NativeEditorMarkdownParser.markdown(from: [block])

        #expect(markdown == """
        - [ ] First line
              Second line
        """)

        let importedBlock = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)
        #expect(importedBlock.kind == .taskListItem(isChecked: false))
        #expect(String(importedBlock.text.characters) == "First line\nSecond line")
    }

    @Test func markdownImportSupportsPlusListMarkers() throws {
        let blocks = NativeEditorMarkdownParser.blocks(from: """
        + Release notes
        + [ ] QA pass
        + [x] Ship build
        """)

        try #require(blocks.count == 3)
        #expect(blocks[0].kind == .bulletListItem)
        #expect(String(blocks[0].text.characters) == "Release notes")
        #expect(blocks[1].kind == .taskListItem(isChecked: false))
        #expect(String(blocks[1].text.characters) == "QA pass")
        #expect(blocks[2].kind == .taskListItem(isChecked: true))
        #expect(String(blocks[2].text.characters) == "Ship build")
    }

    @Test func markdownInputRuleSupportsPlusListMarkers() throws {
        let bulletRule = try #require(NativeEditorMarkdownParser.inputRule(from: "+ Release notes"))
        let uncheckedTaskRule = try #require(NativeEditorMarkdownParser.inputRule(from: "+ [ ] QA pass"))
        let checkedTaskRule = try #require(NativeEditorMarkdownParser.inputRule(from: "+ [x] Ship build"))

        #expect(bulletRule.kind == .bulletListItem)
        #expect(bulletRule.text == "Release notes")
        #expect(uncheckedTaskRule.kind == .taskListItem(isChecked: false))
        #expect(uncheckedTaskRule.text == "QA pass")
        #expect(checkedTaskRule.kind == .taskListItem(isChecked: true))
        #expect(checkedTaskRule.text == "Ship build")
    }
}
