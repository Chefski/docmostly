import Foundation
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

    private func proseMirrorTextMarks(from viewModel: NativeRichEditorViewModel) -> [ProseMirrorMark] {
        viewModel.document.proseMirrorDocument.content.first?.content?.first?.marks ?? []
    }
}
