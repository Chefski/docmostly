import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorFocusLifecycleTests {
    @Test func nativeTextInputFocusDrivesToolbarVisibilityAndIgnoresStaleBlur() {
        let firstBlock = NativeEditorBlock(kind: .paragraph, text: AttributedString("First"), alignment: .left)
        let secondBlock = NativeEditorBlock(kind: .paragraph, text: AttributedString("Second"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [firstBlock, secondBlock])

        viewModel.focus(blockID: firstBlock.id)
        #expect(viewModel.isEditing == false)

        viewModel.textInputDidBeginEditing(blockID: firstBlock.id)
        #expect(viewModel.isEditing == true)
        #expect(viewModel.focusedTextInputBlockID == firstBlock.id)

        viewModel.focus(blockID: secondBlock.id)
        viewModel.textInputDidBeginEditing(blockID: secondBlock.id)
        viewModel.textInputDidEndEditing(blockID: firstBlock.id)

        #expect(viewModel.isEditing == true)
        #expect(viewModel.activeBlockID == secondBlock.id)
        #expect(viewModel.focusedTextInputBlockID == secondBlock.id)

        viewModel.textInputDidEndEditing(blockID: secondBlock.id)
        #expect(viewModel.isEditing == false)
        #expect(viewModel.activeBlockID == nil)
    }

    @Test func deletingFocusedBlockPreservesDestinationAcrossOldInputBlur() {
        let firstBlock = NativeEditorBlock(kind: .paragraph, text: AttributedString("First"), alignment: .left)
        let deletedBlock = NativeEditorBlock(kind: .paragraph, text: AttributedString("Delete"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [firstBlock, deletedBlock])
        viewModel.textInputDidBeginEditing(blockID: deletedBlock.id)

        let destinationBlockID = viewModel.deleteBlock(deletedBlock.id)
        viewModel.textInputDidEndEditing(blockID: deletedBlock.id)

        #expect(destinationBlockID == firstBlock.id)
        #expect(viewModel.activeBlockID == firstBlock.id)
        #expect(viewModel.focusedTextInputBlockID == nil)

        viewModel.textInputDidBeginEditing(blockID: firstBlock.id)
        #expect(viewModel.isEditing == true)
        #expect(viewModel.focusedTextInputBlockID == firstBlock.id)
    }
}
