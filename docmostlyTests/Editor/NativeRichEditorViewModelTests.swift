import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeRichEditorViewModelTests {
    @Test func togglesInlineMarkAcrossActiveBlockWhenSelectionIsMissing() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("Native editor"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.toggleInlineMark(.bold)

        let updatedBlock = viewModel.document.blocks[0]
        #expect(updatedBlock.text.runs.first?.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
        #expect(viewModel.isDirty == true)
    }

    @Test func changesActiveBlockKind() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("Section"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.setActiveBlockKind(.heading(level: 2))

        #expect(viewModel.document.blocks[0].kind == .heading(level: 2))
        #expect(viewModel.isDirty == true)
    }

    @Test func filtersSlashCommandsFromActiveBlockText() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("/to"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        #expect(viewModel.isShowingSlashCommands == true)
        #expect(viewModel.slashCommandQuery == "to")
        #expect(viewModel.filteredSlashCommands.map(\.title) == ["To-do List"])
    }

    @Test func applyingSlashCommandTransformsActiveBlockAndClearsSlashToken() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("/h1"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.applySlashCommand(.heading1)

        #expect(viewModel.document.blocks[0].kind == .heading(level: 1))
        #expect(String(viewModel.document.blocks[0].text.characters).isEmpty)
        #expect(viewModel.isShowingSlashCommands == false)
        #expect(viewModel.isDirty == true)
    }

    @Test func deletesSelectedBlockAndKeepsAdjacentBlockActive() {
        let firstBlock = NativeEditorBlock(kind: .paragraph, text: AttributedString("First"), alignment: .left)
        let selectedBlock = NativeEditorBlock(kind: .paragraph, text: AttributedString("Selected"), alignment: .left)
        let lastBlock = NativeEditorBlock(kind: .paragraph, text: AttributedString("Last"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [firstBlock, selectedBlock, lastBlock])

        viewModel.selectBlock(selectedBlock.id)
        viewModel.deleteSelectedBlock()

        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["First", "Last"])
        #expect(viewModel.selectedBlockID == nil)
        #expect(viewModel.activeBlockID == lastBlock.id)
        #expect(viewModel.isDirty == true)
    }

    @Test func selectingAlreadySelectedBlockClearsSelection() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("Selected"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])

        viewModel.selectBlock(block.id)
        viewModel.selectBlock(block.id)

        #expect(viewModel.selectedBlockID == nil)
        #expect(viewModel.visibleBlockControlsID == block.id)
    }

    @Test func movesBlockBeforeDropTarget() {
        let firstBlock = NativeEditorBlock(kind: .paragraph, text: AttributedString("First"), alignment: .left)
        let secondBlock = NativeEditorBlock(kind: .paragraph, text: AttributedString("Second"), alignment: .left)
        let thirdBlock = NativeEditorBlock(kind: .paragraph, text: AttributedString("Third"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [firstBlock, secondBlock, thirdBlock])

        viewModel.moveBlock(thirdBlock.id, before: firstBlock.id)

        #expect(viewModel.document.blocks.map { String($0.text.characters) } == ["Third", "First", "Second"])
        #expect(viewModel.isDirty == true)
    }
}
