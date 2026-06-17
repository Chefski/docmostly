import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeInlineCommentResolutionTests {
    @Test func updatesInlineCommentResolvedMarksByID() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("Marked text"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)
        viewModel.applyInlineComment(commentID: "comment-1")

        viewModel.setInlineCommentResolved(commentID: "comment-1", isResolved: true)

        let marks = proseMirrorTextMarks(from: viewModel)
        #expect(marks.contains(ProseMirrorMark(
            type: "comment",
            attrs: ["commentId": .string("comment-1"), "resolved": .bool(true)]
        )))
    }

    @Test func removesInlineCommentMarksByIDWithoutTouchingOtherComments() {
        var text = markedText("First", commentID: "comment-1")
        text += AttributedString(" ")
        text += markedText("Second", commentID: "comment-2")
        let block = NativeEditorBlock(kind: .paragraph, text: text, alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])

        viewModel.removeInlineComment(commentID: "comment-1")

        let marks = proseMirrorMarks(from: viewModel)
        #expect(marks.contains(ProseMirrorMark(
            type: "comment",
            attrs: ["commentId": .string("comment-1"), "resolved": .bool(false)]
        )) == false)
        #expect(marks.contains(ProseMirrorMark(
            type: "comment",
            attrs: ["commentId": .string("comment-2"), "resolved": .bool(false)]
        )))
    }

    private func markedText(_ text: String, commentID: String) -> AttributedString {
        var attributedText = AttributedString(text)
        attributedText[NativeEditorCommentIDAttribute.self] = commentID
        attributedText[NativeEditorCommentResolvedAttribute.self] = false
        attributedText.backgroundColor = .yellow.opacity(0.28)
        return attributedText
    }

    private func proseMirrorTextMarks(from viewModel: NativeRichEditorViewModel) -> [ProseMirrorMark] {
        viewModel.document.proseMirrorDocument.content.first?.content?.first?.marks ?? []
    }

    private func proseMirrorMarks(from viewModel: NativeRichEditorViewModel) -> [ProseMirrorMark] {
        viewModel.document.proseMirrorDocument.content.first?.content?.flatMap { node in
            node.marks ?? []
        } ?? []
    }
}
