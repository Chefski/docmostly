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

    @Test func markdownInputRuleSupportsDocmostHeadingThreeShortcut() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString(""), alignment: .left)
        let viewModel = configuredViewModel(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.document.blocks[0].text = AttributedString("### Release details")
        viewModel.handleDocumentChanged()

        #expect(viewModel.document.blocks[0].kind == .heading(level: 3))
        #expect(String(viewModel.document.blocks[0].text.characters) == "Release details")
    }

    @Test func markdownInputRuleSupportsDividerShortcut() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString(""), alignment: .left)
        let viewModel = configuredViewModel(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.document.blocks[0].text = AttributedString("---")
        viewModel.handleDocumentChanged()

        #expect(viewModel.document.blocks[0].kind == .divider)
        #expect(String(viewModel.document.blocks[0].text.characters) == "Divider")
        #expect(viewModel.markdownForDocument() == "---")
    }

    @Test func markdownInputRuleSupportsDocmostDetailsShortcut() throws {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString(""), alignment: .left)
        let viewModel = configuredViewModel(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.document.blocks[0].text = AttributedString(":::details ")
        viewModel.handleDocumentChanged()

        guard case .details(let details) = viewModel.document.blocks[0].kind else {
            Issue.record("Expected Docmost details shortcut to create a native details block.")
            return
        }
        #expect(details.summary == "Details")
        #expect(details.previewText == "Details")
        #expect(String(viewModel.document.blocks[0].text.characters) == "Details")

        let node = viewModel.document.proseMirrorDocument.content[0]
        #expect(node.type == "details")
        #expect(node.attrs?["open"] == .bool(true))
        #expect(node.content?.first?.type == "detailsSummary")
        #expect(node.content?.first?.content?.first?.text == "Details")
        #expect(node.content?[1].type == "detailsContent")
        #expect(node.content?[1].content?.first?.content?.first?.text == "Details")

        viewModel.undo()

        #expect(viewModel.document.blocks[0].kind == .paragraph)
        #expect(String(viewModel.document.blocks[0].text.characters).isEmpty)
    }

    @Test func markdownInputRuleSupportsDocmostDefaultCalloutShortcut() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString(""), alignment: .left)
        let viewModel = configuredViewModel(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.document.blocks[0].text = AttributedString("::: ")
        viewModel.handleDocumentChanged()

        guard case .callout(let callout) = viewModel.document.blocks[0].kind else {
            Issue.record("Expected Docmost callout shortcut to create a native callout block.")
            return
        }
        #expect(callout.style == "info")
        #expect(callout.previewText == "Callout")
        #expect(String(viewModel.document.blocks[0].text.characters) == "Callout")
        #expect(viewModel.document.proseMirrorDocument.content[0].type == "callout")
        #expect(viewModel.document.proseMirrorDocument.content[0].attrs?["type"] == .string("info"))
    }

    @Test func markdownInputRuleSupportsDocmostTypedCalloutShortcut() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString(""), alignment: .left)
        let viewModel = configuredViewModel(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.document.blocks[0].text = AttributedString(":::warning ")
        viewModel.handleDocumentChanged()

        guard case .callout(let callout) = viewModel.document.blocks[0].kind else {
            Issue.record("Expected Docmost typed callout shortcut to create a native callout block.")
            return
        }
        #expect(callout.style == "warning")
        #expect(String(viewModel.document.blocks[0].text.characters) == "Callout")
        #expect(viewModel.document.proseMirrorDocument.content[0].attrs?["type"] == .string("warning"))
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

    @Test func pasteMarkdownTableCreatesNativeTableBlock() throws {
        let intro = NativeEditorBlock(kind: .paragraph, text: AttributedString("Intro"), alignment: .left)
        let viewModel = configuredViewModel(blocks: [intro])
        viewModel.focus(blockID: intro.id)

        viewModel.pasteMarkdown("""
        | Feature | Status |
        | --- | --- |
        | Tables | Native |
        | Paste | Done |
        """)

        #expect(viewModel.document.blocks.count == 2)

        let tableBlock = try #require(viewModel.document.blocks.dropFirst().first)
        guard case .table(let table) = tableBlock.kind else {
            Issue.record("Expected pasted Markdown table to become a native table block.")
            return
        }

        #expect(table.rows.map { $0.cells.map(\.plainText) } == [
            ["Feature", "Status"],
            ["Tables", "Native"],
            ["Paste", "Done"]
        ])
        let headerFlags = table.rows[0].cells.map(\.isHeader)
        let bodyHeaderFlags = table.rows.dropFirst().flatMap { $0.cells.map(\.isHeader) }
        #expect(headerFlags == Array(repeating: true, count: headerFlags.count))
        #expect(bodyHeaderFlags == Array(repeating: false, count: bodyHeaderFlags.count))

        let tableNode = viewModel.document.proseMirrorDocument.content.last
        #expect(tableNode?.type == "table")
        #expect(tableNode?.content?.first?.content?.first?.type == "tableHeader")
        #expect(tableNode?.content?.dropFirst().first?.content?.first?.type == "tableCell")
        #expect(viewModel.markdownForDocument() == """
        Intro
        | Feature | Status |
        | --- | --- |
        | Tables | Native |
        | Paste | Done |
        """)
    }

    @Test func pasteMarkdownTablePreservesInlineMarksInCells() throws {
        let intro = NativeEditorBlock(kind: .paragraph, text: AttributedString("Intro"), alignment: .left)
        let viewModel = configuredViewModel(blocks: [intro])
        viewModel.focus(blockID: intro.id)

        viewModel.pasteMarkdown("""
        | Feature | Source |
        | --- | --- |
        | **Tables** | [Spec](https://example.com/spec) |
        """)

        guard case .table(let table) = viewModel.document.blocks[1].kind else {
            Issue.record("Expected pasted Markdown table to become a native table block.")
            return
        }

        #expect(table.rows[1].cells.map(\.plainText) == ["Tables", "Spec"])

        let bodyRow = try #require(viewModel.document.proseMirrorDocument.content.last?.content?.dropFirst().first)
        let firstCellText = try #require(bodyRow.content?[0].content?.first?.content?.first)
        let secondCellText = try #require(bodyRow.content?[1].content?.first?.content?.first)

        #expect(firstCellText.text == "Tables")
        #expect(firstCellText.marks?.contains(ProseMirrorMark(type: "bold")) == true)
        #expect(secondCellText.text == "Spec")
        #expect(
            secondCellText.marks?.contains(
                ProseMirrorMark(type: "link", attrs: ["href": .string("https://example.com/spec")])
            ) == true
        )
    }

    @Test func pasteMarkdownRichBlocksCreatesNativeBlocks() throws {
        let intro = NativeEditorBlock(kind: .paragraph, text: AttributedString("Intro"), alignment: .left)
        let viewModel = configuredViewModel(blocks: [intro])
        viewModel.focus(blockID: intro.id)

        viewModel.pasteMarkdown("""
        ![Architecture](/files/image.png)
        :::warning
        Check migration plan
        :::
        $$
        E = mc^2
        $$
        """)

        #expect(viewModel.document.blocks.count == 4)

        guard case .image(let image) = viewModel.document.blocks[1].kind else {
            Issue.record("Expected pasted Markdown image to become a native image block.")
            return
        }
        #expect(image.source == "/files/image.png")
        #expect(image.alternativeText == "Architecture")

        guard case .callout(let callout) = viewModel.document.blocks[2].kind else {
            Issue.record("Expected pasted Markdown callout to become a native callout block.")
            return
        }
        #expect(callout.style == "warning")
        #expect(callout.previewText == "Check migration plan")

        guard case .mathBlock(let math) = viewModel.document.blocks[3].kind else {
            Issue.record("Expected pasted Markdown math fence to become a native math block.")
            return
        }
        #expect(math.text == "E = mc^2")
    }

    @Test func pasteMarkdownInlineMathCreatesDocmostInlineAtom() throws {
        let intro = NativeEditorBlock(kind: .paragraph, text: AttributedString("Intro"), alignment: .left)
        let viewModel = configuredViewModel(blocks: [intro])
        viewModel.focus(blockID: intro.id)

        viewModel.pasteMarkdown("Formula $E = mc^2$ today")

        let inlineNodes = viewModel.document.proseMirrorDocument.content.last?.content ?? []
        #expect(inlineNodes.map(\.type) == ["text", "mathInline", "text"])
        #expect(inlineNodes[0].text == "Formula ")
        #expect(inlineNodes[1].attrs?["text"] == .string("E = mc^2"))
        #expect(inlineNodes[2].text == " today")
    }

    @Test func pasteMarkdownInlineMathPreservesSurroundingInlineMarks() {
        let intro = NativeEditorBlock(kind: .paragraph, text: AttributedString("Intro"), alignment: .left)
        let viewModel = configuredViewModel(blocks: [intro])
        viewModel.focus(blockID: intro.id)

        viewModel.pasteMarkdown("Formula **important** $E = mc^2$ `today`")

        let inlineNodes = viewModel.document.proseMirrorDocument.content.last?.content ?? []
        #expect(inlineNodes.map(\.type) == ["text", "text", "text", "mathInline", "text", "text"])
        #expect(inlineNodes[1].text == "important")
        #expect(inlineNodes[1].marks?.contains(ProseMirrorMark(type: "bold")) == true)
        #expect(inlineNodes[3].attrs?["text"] == .string("E = mc^2"))
        #expect(inlineNodes[5].text == "today")
        #expect(inlineNodes[5].marks?.contains(ProseMirrorMark(type: "code")) == true)
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

    @Test func documentMarkdownConversionPreservesInlineMathAtom() {
        var text = AttributedString("Formula ")
        var mathText = AttributedString("E = mc^2")
        mathText[NativeEditorMathInlineAttribute.self] = NativeEditorMathInline(text: "E = mc^2")
        mathText.inlinePresentationIntent = .code
        text += mathText
        text += AttributedString(" today")

        let block = NativeEditorBlock(kind: .paragraph, text: text, alignment: .left)
        let viewModel = configuredViewModel(blocks: [block])

        #expect(viewModel.markdownForDocument() == "Formula $E = mc^2$ today")
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
