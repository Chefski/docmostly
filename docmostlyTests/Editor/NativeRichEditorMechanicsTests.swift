import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeRichEditorMechanicsTests {
    @Test func undoRedoRestoresBlockKindChanges() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("Title"), alignment: .left)
        let viewModel = configuredViewModel(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.setActiveBlockKind(.heading(level: 1))

        #expect(viewModel.canUndo == true)
        #expect(viewModel.canRedo == false)
        #expect(viewModel.document.blocks[0].kind == .heading(level: 1))

        viewModel.undo()

        #expect(viewModel.document.blocks[0].kind == .paragraph)
        #expect(viewModel.canRedo == true)

        viewModel.redo()

        #expect(viewModel.document.blocks[0].kind == .heading(level: 1))
    }

    @Test func markdownInputRuleTransformsActiveBlockAndParticipatesInUndo() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString(""), alignment: .left)
        let viewModel = configuredViewModel(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.document.blocks[0].text = AttributedString("## Release notes")
        viewModel.handleDocumentChanged()

        #expect(viewModel.document.blocks[0].kind == .heading(level: 2))
        #expect(String(viewModel.document.blocks[0].text.characters) == "Release notes")

        viewModel.undo()

        #expect(viewModel.document.blocks[0].kind == .paragraph)
        #expect(String(viewModel.document.blocks[0].text.characters).isEmpty)
    }

    @Test func pasteMarkdownInsertsNativeBlocksAfterActiveBlock() {
        let intro = NativeEditorBlock(kind: .paragraph, text: AttributedString("Intro"), alignment: .left)
        let viewModel = configuredViewModel(blocks: [intro])
        viewModel.focus(blockID: intro.id)

        viewModel.pasteMarkdown("""
        # Roadmap
        - Native paste
        2. Ordered step
        """)

        #expect(viewModel.document.blocks.map(\.kind) == [
            .paragraph,
            .heading(level: 1),
            .bulletListItem,
            .orderedListItem(ordinal: 2)
        ])
        #expect(String(viewModel.document.blocks[1].text.characters) == "Roadmap")

        viewModel.undo()

        #expect(viewModel.document.blocks.count == 1)
        #expect(String(viewModel.document.blocks[0].text.characters) == "Intro")
    }

    @Test func pasteMarkdownPreservesNestedListIndentation() {
        let intro = NativeEditorBlock(kind: .paragraph, text: AttributedString("Intro"), alignment: .left)
        let viewModel = configuredViewModel(blocks: [intro])
        viewModel.focus(blockID: intro.id)

        viewModel.pasteMarkdown("""
        - Parent
          - Child
            - Grandchild
          2. Ordered child
          - [x] Task child
        """)

        #expect(viewModel.document.blocks.map(\.indentLevel) == [0, 0, 1, 2, 1, 1])
        #expect(viewModel.document.blocks.map(\.kind) == [
            .paragraph,
            .bulletListItem,
            .bulletListItem,
            .bulletListItem,
            .orderedListItem(ordinal: 2),
            .taskListItem(isChecked: true)
        ])
    }

    @Test func indentAndOutdentActiveListBlock() {
        let block = NativeEditorBlock(kind: .bulletListItem, text: AttributedString("Nested"), alignment: .left)
        let viewModel = configuredViewModel(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.indentActiveBlock()

        #expect(viewModel.document.blocks[0].indentLevel == 1)

        viewModel.outdentActiveBlock()

        #expect(viewModel.document.blocks[0].indentLevel == 0)
    }

    @Test func smartTypographyNormalizesPlainTextEdits() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString(""), alignment: .left)
        let viewModel = configuredViewModel(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.document.blocks[0].text = AttributedString("Wait... A -> B")
        viewModel.handleDocumentChanged()

        #expect(String(viewModel.document.blocks[0].text.characters) == "Wait… A → B")
    }

    @Test func searchReplaceUpdatesMatchesAndSupportsUndo() {
        let first = NativeEditorBlock(kind: .paragraph, text: AttributedString("Alpha beta"), alignment: .left)
        let second = NativeEditorBlock(kind: .paragraph, text: AttributedString("beta gamma"), alignment: .left)
        let viewModel = configuredViewModel(blocks: [first, second])

        viewModel.searchQuery = "beta"
        viewModel.replacementText = "done"

        #expect(viewModel.searchMatches.count == 2)

        viewModel.replaceAllSearchMatches()

        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["Alpha done", "done gamma"])

        viewModel.undo()

        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["Alpha beta", "beta gamma"])
    }

    @Test func searchNavigationSelectsExactMatchInFocusedBlock() throws {
        let first = NativeEditorBlock(kind: .paragraph, text: AttributedString("Alpha beta"), alignment: .left)
        let second = NativeEditorBlock(kind: .paragraph, text: AttributedString("Gamma beta"), alignment: .left)
        let viewModel = configuredViewModel(blocks: [first, second])

        viewModel.searchQuery = "beta"
        viewModel.selectNextSearchMatch()

        #expect(viewModel.activeBlockID == second.id)

        let selectedText = try selectedPlainText(in: viewModel.document.blocks[1])
        #expect(selectedText == "beta")
    }

    @Test func documentMarkdownConversionIncludesBlockStructure() {
        let heading = NativeEditorBlock(kind: .heading(level: 1), text: AttributedString("Roadmap"), alignment: .left)
        let item = NativeEditorBlock(
            kind: .taskListItem(isChecked: true),
            text: AttributedString("Ship editor"),
            alignment: .left
        )
        let viewModel = configuredViewModel(blocks: [heading, item])

        #expect(viewModel.markdownForDocument() == "# Roadmap\n- [x] Ship editor")
    }

    private func configuredViewModel(blocks: [NativeEditorBlock]) -> NativeRichEditorViewModel {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: blocks)
        viewModel.resetEditingHistory()
        return viewModel
    }

    private func selectedPlainText(in block: NativeEditorBlock) throws -> String {
        switch block.selection.indices(in: block.text) {
        case .ranges(let ranges):
            let range = try #require(ranges.ranges.first)
            return String(block.text[range].characters)
        case .insertionPoint:
            return ""
        }
    }
}
