import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeRichEditorInlineTypingTests {
    @Test func togglesInlineMarkForTypingWithoutChangingExistingText() {
        let block = NativeEditorBlock(
            kind: .paragraph,
            text: AttributedString("Native editor"),
            alignment: .left
        )
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.toggleInlineMark(.bold)

        let updatedBlock = viewModel.document.blocks[0]
        #expect(updatedBlock.text == block.text)
        #expect(viewModel.typingInlineMarks(for: block.id).contains(.bold))
        #expect(viewModel.isInlineMarkActive(.bold))
        #expect(viewModel.isDirty == false)

        viewModel.toggleInlineMark(.bold)

        #expect(viewModel.typingInlineMarks(for: block.id).contains(.bold) == false)
        #expect(viewModel.isInlineMarkActive(.bold) == false)
    }

    @Test func togglesInlineMarkAcrossSelectedText() {
        let text = AttributedString("Native editor")
        let selectedRange = text.startIndex..<text.endIndex
        let block = NativeEditorBlock(
            kind: .paragraph,
            text: text,
            alignment: .left,
            selection: AttributedTextSelection(range: selectedRange)
        )
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.toggleInlineMark(.italic)

        let updatedText = viewModel.document.blocks[0].text
        #expect(updatedText.runs.allSatisfy {
            $0.inlinePresentationIntent?.contains(.emphasized) == true
        })
        #expect(viewModel.isInlineMarkActive(.italic))
        #expect(viewModel.isDirty)
    }
}
