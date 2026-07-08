import Foundation
import Testing
@testable import docmostly

struct NativeEditorBlockRowPolicyTests {
    @Test func editModeShowsTextEditorForNonFocusedEditableBlocks() {
        let block = NativeEditorBlock(
            kind: .paragraph,
            text: AttributedString("Editable body"),
            alignment: .left
        )

        #expect(NativeEditorBlockRowPolicy.showsEditableTextEditor(block: block, isReadOnly: false))
    }

    @Test func readModeDoesNotShowTextEditorForEditableBlocks() {
        let block = NativeEditorBlock(
            kind: .paragraph,
            text: AttributedString("Read-only body"),
            alignment: .left
        )

        #expect(NativeEditorBlockRowPolicy.showsEditableTextEditor(block: block, isReadOnly: true) == false)
    }

    @Test func readModeDisablesTaskListToggles() {
        #expect(NativeEditorBlockRowPolicy.allowsTaskToggle(isReadOnly: false))
        #expect(NativeEditorBlockRowPolicy.allowsTaskToggle(isReadOnly: true) == false)
    }
}
