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

    @Test func readModePreservesPrefixesForListAndUnsupportedBlocks() {
        #expect(NativeEditorBlockRowPolicy.hasVisiblePrefix(kind: .bulletListItem))
        #expect(NativeEditorBlockRowPolicy.hasVisiblePrefix(kind: .orderedListItem(ordinal: 2)))
        #expect(NativeEditorBlockRowPolicy.hasVisiblePrefix(kind: .taskListItem(isChecked: true)))
        #expect(NativeEditorBlockRowPolicy.hasVisiblePrefix(kind: .unsupported(type: "custom")))
        #expect(NativeEditorBlockRowPolicy.hasVisiblePrefix(kind: .paragraph) == false)
        #expect(NativeEditorBlockRowPolicy.hasVisiblePrefix(kind: .blockquote) == false)
    }
}
