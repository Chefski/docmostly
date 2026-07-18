import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeRichEditorBlockMechanicsTests {
    @Test func splitReplacesSelectionAndPreservesAttributedRuns() throws {
        var prefix = AttributedString("Alpha ")
        prefix.inlinePresentationIntent = .stronglyEmphasized
        var removed = AttributedString("remove ")
        removed.foregroundColor = .red
        var suffix = AttributedString("Omega")
        suffix[NativeEditorStatusAttribute.self] = NativeEditorStatusBadge(text: "Omega", color: "green")
        let block = NativeEditorBlock(
            kind: .paragraph,
            text: prefix + removed + suffix,
            alignment: .center,
            indentLevel: 2
        )
        let viewModel = configuredViewModel(blocks: [block])

        let continuationID = try #require(viewModel.splitBlock(block.id, replacing: 6..<13))

        #expect(viewModel.document.blocks.map(plainText) == ["Alpha ", "Omega"])
        #expect(viewModel.document.blocks[0].text.runs.first?.inlinePresentationIntent == .stronglyEmphasized)
        #expect(
            viewModel.document.blocks[1].text.runs.first?[NativeEditorStatusAttribute.self] ==
                NativeEditorStatusBadge(text: "Omega", color: "green")
        )
        #expect(viewModel.document.blocks[1].alignment == .center)
        #expect(viewModel.document.blocks[1].indentLevel == 2)
        #expect(viewModel.activeBlockID == continuationID)
        #expect(try insertionOffset(in: viewModel.document.blocks[1]) == 0)
        #expect(viewModel.undoStack.count == 1)

        viewModel.undo()

        #expect(viewModel.document.blocks.count == 1)
        #expect(plainText(viewModel.document.blocks[0]) == "Alpha remove Omega")
        #expect(
            viewModel.document.blocks[0].text.runs.contains {
                $0[NativeEditorStatusAttribute.self] == NativeEditorStatusBadge(text: "Omega", color: "green")
            }
        )
    }

    @Test func splitUsesCharacterOffsetsForExtendedGraphemeClusters() throws {
        let block = NativeEditorBlock(
            kind: .paragraph,
            text: AttributedString("A👨‍👩‍👧‍👦B"),
            alignment: .left
        )
        let viewModel = configuredViewModel(blocks: [block])

        _ = try #require(viewModel.splitBlock(block.id, at: 2))

        #expect(viewModel.document.blocks.map(plainText) == ["A👨‍👩‍👧‍👦", "B"])
    }

    @Test func headingSplitAtEndStartsAnUnstyledParagraph() throws {
        let block = NativeEditorBlock(
            kind: .heading(level: 2),
            text: AttributedString("Heading"),
            alignment: .center,
            indentLevel: 3
        )
        let viewModel = configuredViewModel(blocks: [block])

        _ = try #require(viewModel.splitBlock(block.id, at: 7))

        #expect(viewModel.document.blocks.map(\.kind) == [.heading(level: 2), .paragraph])
        #expect(viewModel.document.blocks[1].alignment == .left)
        #expect(viewModel.document.blocks[1].indentLevel == 0)
    }

    @Test func headingSplitInTheMiddleContinuesHeadingStyle() throws {
        let block = NativeEditorBlock(
            kind: .heading(level: 2),
            text: AttributedString("Heading"),
            alignment: .right,
            indentLevel: 1
        )
        let viewModel = configuredViewModel(blocks: [block])

        _ = try #require(viewModel.splitBlock(block.id, at: 4))

        #expect(viewModel.document.blocks.map(plainText) == ["Head", "ing"])
        #expect(viewModel.document.blocks.map(\.kind) == [.heading(level: 2), .heading(level: 2)])
        #expect(viewModel.document.blocks[1].alignment == .right)
        #expect(viewModel.document.blocks[1].indentLevel == 1)
    }
}

@MainActor
struct NativeEditorReturnSemanticsTests {
    @Test func emptyHeadingReturnKeepsHeadingAndStartsParagraph() throws {
        let block = NativeEditorBlock(
            kind: .heading(level: 2),
            text: AttributedString(""),
            alignment: .right,
            indentLevel: 1
        )
        let viewModel = configuredViewModel(blocks: [block])

        let paragraphID = try #require(viewModel.splitBlock(block.id, at: 0))

        #expect(viewModel.document.blocks.map(\.kind) == [.heading(level: 2), .paragraph])
        #expect(viewModel.document.blocks.map(plainText) == ["", ""])
        #expect(viewModel.document.blocks[0].alignment == .right)
        #expect(viewModel.document.blocks[0].indentLevel == 1)
        #expect(viewModel.activeBlockID == paragraphID)
    }

    @Test func blockquoteEndReturnContinuesQuoteThenEmptyReturnExits() throws {
        let block = NativeEditorBlock(
            kind: .blockquote,
            text: AttributedString("Quoted"),
            alignment: .left
        )
        let viewModel = configuredViewModel(blocks: [block])

        let emptyQuoteID = try #require(viewModel.splitBlock(block.id, at: 6))

        #expect(viewModel.document.blocks.map(\.kind) == [.blockquote, .blockquote])
        #expect(viewModel.document.blocks.map(plainText) == ["Quoted", ""])
        #expect(viewModel.activeBlockID == emptyQuoteID)

        let paragraphID = try #require(viewModel.splitBlock(emptyQuoteID, at: 0))

        #expect(paragraphID == emptyQuoteID)
        #expect(viewModel.document.blocks.map(\.kind) == [.blockquote, .paragraph])
        #expect(viewModel.document.blocks.map(plainText) == ["Quoted", ""])
        #expect(viewModel.activeBlockID == emptyQuoteID)
        #expect(viewModel.undoStack.count == 2)
    }

    @Test func emptyBlockquoteExitPreservesLiftedParagraphAttributes() throws {
        let original = try JSONDecoder().decode(
            ProseMirrorDocument.self,
            from: Data("""
            {
              "type": "doc",
              "content": [{
                "type": "blockquote",
                "attrs": { "tone": "muted" },
                "content": [{
                  "type": "paragraph",
                  "attrs": { "id": "paragraph-1", "custom": "preserved" }
                }]
              }]
            }
            """.utf8)
        )
        let viewModel = configuredViewModel(
            blocks: NativeEditorDocument(proseMirrorDocument: original).blocks
        )
        let quoteID = try #require(viewModel.document.blocks.first?.id)
        let baseline = viewModel.document.proseMirrorDocument

        let paragraphID = try #require(viewModel.splitBlock(quoteID, at: 0))

        let paragraph = try #require(viewModel.document.proseMirrorDocument.content.first)
        #expect(paragraphID == quoteID)
        #expect(viewModel.document.blocks.map(\.kind) == [.paragraph])
        #expect(paragraph.type == "paragraph")
        #expect(paragraph.attrs?["custom"]?.stringValue == "preserved")
        #expect(paragraph.attrs?["id"]?.stringValue == "paragraph-1")
        #expect(paragraph.attrs?["tone"] == nil)

        viewModel.undo()

        #expect(viewModel.document.proseMirrorDocument == baseline)
    }

    @Test func emptyRawBlockquoteRefusesToDiscardAdditionalChildren() throws {
        let original = try JSONDecoder().decode(
            ProseMirrorDocument.self,
            from: Data("""
            {
              "type": "doc",
              "content": [{
                "type": "blockquote",
                "content": [
                  { "type": "paragraph" },
                  { "type": "paragraph", "content": [{ "type": "text", "text": "Preserved" }] }
                ]
              }]
            }
            """.utf8)
        )
        let viewModel = configuredViewModel(
            blocks: NativeEditorDocument(proseMirrorDocument: original).blocks
        )
        let quoteID = try #require(viewModel.document.blocks.first?.id)
        let baseline = viewModel.document.proseMirrorDocument

        #expect(viewModel.splitBlock(quoteID, at: 0) == nil)
        #expect(viewModel.document.proseMirrorDocument == baseline)
        #expect(viewModel.undoStack.isEmpty)
    }

    @Test func codeBlockReturnInsertsNewlineWithoutLeavingCode() throws {
        let block = NativeEditorBlock(
            kind: .codeBlock(language: "swift"),
            text: AttributedString("let value = 1"),
            alignment: .left
        )
        let viewModel = configuredViewModel(blocks: [block])

        #expect(viewModel.insertSoftBreak(in: block.id, at: 13))

        #expect(viewModel.document.blocks.map(\.kind) == [.codeBlock(language: "swift")])
        #expect(viewModel.document.blocks.map(plainText) == ["let value = 1\n"])
        #expect(viewModel.document.proseMirrorDocument.content.first?.content?.first?.text == "let value = 1\n")
    }

    @Test func emptyCodeBlockReturnInsertsNewlineWithoutLeavingCode() throws {
        let block = NativeEditorBlock(
            kind: .codeBlock(language: nil),
            text: AttributedString(""),
            alignment: .left
        )
        let viewModel = configuredViewModel(blocks: [block])

        #expect(viewModel.insertSoftBreak(in: block.id, at: 0))

        #expect(viewModel.document.blocks.map(\.kind) == [.codeBlock(language: nil)])
        #expect(viewModel.document.blocks.map(plainText) == ["\n"])
        #expect(viewModel.document.blocks.count == 1)
    }

    @Test func tripleReturnCodeExitRemovesSentinelBlankLines() throws {
        let block = NativeEditorBlock(
            kind: .codeBlock(language: "swift"),
            text: AttributedString("let value = 1\n\n"),
            alignment: .left
        )
        let viewModel = configuredViewModel(blocks: [block])

        let paragraphID = try #require(viewModel.splitBlock(block.id, at: 15))

        #expect(viewModel.document.blocks.map(\.kind) == [
            .codeBlock(language: "swift"),
            .paragraph
        ])
        #expect(viewModel.document.blocks.map(plainText) == ["let value = 1", ""])
        #expect(viewModel.activeBlockID == paragraphID)
        #expect(viewModel.undoStack.count == 1)

        viewModel.undo()

        #expect(viewModel.document.blocks.map(plainText) == ["let value = 1\n\n"])
    }

    @Test func explicitCodeExitAtEndStartsParagraph() throws {
        let block = NativeEditorBlock(
            kind: .codeBlock(language: "swift"),
            text: AttributedString("let value = 1"),
            alignment: .left
        )
        let viewModel = configuredViewModel(blocks: [block])

        let paragraphID = try #require(viewModel.splitBlock(block.id, at: 13))

        #expect(viewModel.document.blocks.map(\.kind) == [
            .codeBlock(language: "swift"),
            .paragraph
        ])
        #expect(viewModel.document.blocks.map(plainText) == ["let value = 1", ""])
        #expect(viewModel.activeBlockID == paragraphID)
    }

    private func configuredViewModel(blocks: [NativeEditorBlock]) -> NativeRichEditorViewModel {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: blocks)
        viewModel.resetEditingHistory()
        return viewModel
    }

    private func plainText(_ block: NativeEditorBlock) -> String {
        String(block.text.characters)
    }
}

extension NativeRichEditorBlockMechanicsTests {
    @Test func softBreakReplacesSelectionAndIsOneUndoableEdit() throws {
        let block = NativeEditorBlock(
            kind: .paragraph,
            text: AttributedString("Hello brave world"),
            alignment: .left
        )
        let viewModel = configuredViewModel(blocks: [block])

        #expect(viewModel.insertSoftBreak(in: block.id, replacing: 6..<12))

        #expect(plainText(viewModel.document.blocks[0]) == "Hello \nworld")
        #expect(try insertionOffset(in: viewModel.document.blocks[0]) == 7)
        #expect(viewModel.document.proseMirrorDocument.content[0].content?.map(\.type) == [
            "text",
            "hardBreak",
            "text"
        ])
        #expect(viewModel.undoStack.count == 1)

        viewModel.undo()

        #expect(plainText(viewModel.document.blocks[0]) == "Hello brave world")
    }

    @Test func continuingTaskItemSplitsTextAndResetsCheckedState() throws {
        let block = NativeEditorBlock(
            kind: .taskListItem(isChecked: true),
            text: AttributedString("Ship today"),
            alignment: .left,
            indentLevel: 1
        )
        let viewModel = configuredViewModel(blocks: [block])

        let continuationID = try #require(viewModel.continueListItem(block.id, at: 5))

        #expect(viewModel.document.blocks.map(plainText) == ["Ship ", "today"])
        #expect(viewModel.document.blocks.map(\.kind) == [
            .taskListItem(isChecked: true),
            .taskListItem(isChecked: false)
        ])
        #expect(viewModel.document.blocks.map(\.indentLevel) == [1, 1])
        #expect(viewModel.activeBlockID == continuationID)
        #expect(viewModel.undoStack.count == 1)
    }

    @Test func continuingOrderedItemRenumbersFollowingSiblings() throws {
        let first = NativeEditorBlock(
            kind: .orderedListItem(ordinal: 4),
            text: AttributedString("Four"),
            alignment: .left
        )
        let second = NativeEditorBlock(
            kind: .orderedListItem(ordinal: 5),
            text: AttributedString("Five"),
            alignment: .left
        )
        let third = NativeEditorBlock(
            kind: .orderedListItem(ordinal: 6),
            text: AttributedString("Six"),
            alignment: .left
        )
        let viewModel = configuredViewModel(blocks: [first, second, third])

        _ = try #require(viewModel.continueListItem(first.id, at: 4))

        #expect(viewModel.document.blocks.map(plainText) == ["Four", "", "Five", "Six"])
        #expect(viewModel.document.blocks.map(\.kind) == [
            .orderedListItem(ordinal: 4),
            .orderedListItem(ordinal: 5),
            .orderedListItem(ordinal: 6),
            .orderedListItem(ordinal: 7)
        ])
    }

    @Test func continuingEmptyTopLevelListItemExitsToParagraph() throws {
        let block = NativeEditorBlock(kind: .bulletListItem, text: AttributedString(""), alignment: .left)
        let viewModel = configuredViewModel(blocks: [block])

        let resultingID = try #require(viewModel.continueListItem(block.id, at: 0))

        #expect(resultingID == block.id)
        #expect(viewModel.document.blocks.count == 1)
        #expect(viewModel.document.blocks[0].kind == .paragraph)
        #expect(viewModel.document.blocks[0].rawNode == nil)
        #expect(viewModel.activeBlockID == block.id)
        #expect(viewModel.undoStack.count == 1)
    }

    @Test func continuingEmptyNestedListItemOutdentsWithoutChangingKind() throws {
        let block = NativeEditorBlock(
            kind: .orderedListItem(ordinal: 8),
            text: AttributedString(""),
            alignment: .left,
            indentLevel: 2
        )
        let viewModel = configuredViewModel(blocks: [block])

        _ = try #require(viewModel.continueListItem(block.id, at: 0))

        #expect(viewModel.document.blocks[0].kind == .orderedListItem(ordinal: 8))
        #expect(viewModel.document.blocks[0].indentLevel == 1)
        #expect(viewModel.undoStack.count == 1)
    }

    @Test func mergePreservesCustomRunsAndPlacesCaretAtJoin() throws {
        var firstText = AttributedString("Plan ")
        firstText.inlinePresentationIntent = .stronglyEmphasized
        var secondText = AttributedString("SET STATUS")
        secondText[NativeEditorStatusAttribute.self] = NativeEditorStatusBadge(text: "", color: "gray")
        secondText.inlinePresentationIntent = .stronglyEmphasized
        let first = NativeEditorBlock(kind: .paragraph, text: firstText, alignment: .left)
        let second = NativeEditorBlock(kind: .paragraph, text: secondText, alignment: .left)
        let viewModel = configuredViewModel(blocks: [first, second])

        #expect(viewModel.mergeBlockBackward(second.id))

        let merged = try #require(viewModel.document.blocks.first)
        #expect(viewModel.document.blocks.count == 1)
        #expect(plainText(merged) == "Plan SET STATUS")
        #expect(try insertionOffset(in: merged) == 5)
        #expect(
            merged.text.runs.contains {
                $0[NativeEditorStatusAttribute.self] == NativeEditorStatusBadge(text: "", color: "gray")
            }
        )
        #expect(viewModel.activeBlockID == first.id)
        #expect(viewModel.undoStack.count == 1)

        viewModel.undo()

        #expect(viewModel.document.blocks.map(plainText) == ["Plan ", "SET STATUS"])
    }

    @Test func mergeRefusesToDiscardAdditionalRawListContent() throws {
        let original = try JSONDecoder().decode(
            ProseMirrorDocument.self,
            from: Data("""
            {
              "type": "doc",
              "content": [
                { "type": "paragraph", "content": [{ "type": "text", "text": "Before" }] },
                {
                  "type": "bulletList",
                  "content": [{
                    "type": "listItem",
                    "content": [
                      { "type": "paragraph", "content": [{ "type": "text", "text": "Visible" }] },
                      { "type": "paragraph", "content": [{ "type": "text", "text": "Preserved" }] }
                    ]
                  }]
                }
              ]
            }
            """.utf8)
        )
        let viewModel = configuredViewModel(
            blocks: NativeEditorDocument(proseMirrorDocument: original).blocks
        )
        let sourceID = try #require(viewModel.document.blocks.last?.id)
        let baseline = viewModel.document.proseMirrorDocument

        #expect(viewModel.mergeBlockBackward(sourceID) == false)
        #expect(viewModel.document.proseMirrorDocument == baseline)
        #expect(viewModel.undoStack.isEmpty)
    }

    @Test func listSplitPreservesAdditionalRawContentOnOriginalItem() throws {
        let original = try JSONDecoder().decode(
            ProseMirrorDocument.self,
            from: Data("""
            {
              "type": "doc",
              "content": [{
                "type": "bulletList",
                "content": [{
                  "type": "listItem",
                  "content": [
                    { "type": "paragraph", "content": [{ "type": "text", "text": "Launch" }] },
                    { "type": "paragraph", "content": [{ "type": "text", "text": "Preserved" }] }
                  ]
                }]
              }]
            }
            """.utf8)
        )
        let viewModel = configuredViewModel(
            blocks: NativeEditorDocument(proseMirrorDocument: original).blocks
        )
        let sourceID = try #require(viewModel.document.blocks.first?.id)

        _ = try #require(viewModel.continueListItem(sourceID, at: 3))

        let items = try #require(viewModel.document.proseMirrorDocument.content.first?.content)
        let originalItem = try #require(items.first)
        let continuationItem = try #require(items.dropFirst().first)
        let originalItemContent = try #require(originalItem.content)
        #expect(items.count == 2)
        try #require(originalItemContent.count == 2)
        #expect(originalItemContent[0].content?.first?.text == "Lau")
        #expect(originalItemContent[1].content?.first?.text == "Preserved")
        #expect(continuationItem.content?.first?.content?.first?.text == "nch")
    }

    @Test func listSplitMovesNestedListToContinuationWithoutDuplicatingIt() throws {
        let original = try JSONDecoder().decode(
            ProseMirrorDocument.self,
            from: Data("""
            {
              "type": "doc",
              "content": [{
                "type": "bulletList",
                "content": [{
                  "type": "listItem",
                  "attrs": { "custom": "preserved" },
                  "content": [
                    { "type": "paragraph", "content": [{ "type": "text", "text": "Launch" }] },
                    {
                      "type": "bulletList",
                      "content": [{
                        "type": "listItem",
                        "content": [
                          { "type": "paragraph", "content": [{ "type": "text", "text": "Nested" }] }
                        ]
                      }]
                    }
                  ]
                }]
              }]
            }
            """.utf8)
        )
        let viewModel = configuredViewModel(
            blocks: NativeEditorDocument(proseMirrorDocument: original).blocks
        )
        let sourceID = try #require(viewModel.document.blocks.first?.id)

        _ = try #require(viewModel.continueListItem(sourceID, at: 3))

        let items = try #require(viewModel.document.proseMirrorDocument.content.first?.content)
        let leadingContent = try #require(items.first?.content)
        let continuationContent = try #require(items.dropFirst().first?.content)
        #expect(items.count == 2)
        #expect(items.first?.attrs?["custom"] == .string("preserved"))
        #expect(leadingContent.contains(where: \.isListContainer) == false)
        #expect(continuationContent.filter(\.isListContainer).count == 1)
        #expect(continuationContent.last?.content?.first?.content?.first?.text == "Nested")
    }

    private func configuredViewModel(blocks: [NativeEditorBlock]) -> NativeRichEditorViewModel {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: blocks)
        viewModel.resetEditingHistory()
        return viewModel
    }

    private func plainText(_ block: NativeEditorBlock) -> String {
        String(block.text.characters)
    }

    private func insertionOffset(in block: NativeEditorBlock) throws -> Int {
        switch block.selection.indices(in: block.text) {
        case .insertionPoint(let index):
            return block.text.characters.distance(from: block.text.startIndex, to: index)
        case .ranges:
            Issue.record("Expected an insertion-point selection")
            return -1
        }
    }
}
