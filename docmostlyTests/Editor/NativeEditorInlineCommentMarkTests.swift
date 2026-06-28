import Foundation
import Testing
@testable import docmostly

struct NativeEditorInlineCommentMarkTests {
    @Test func markdownExportPreservesDocmostInlineCommentSpan() {
        var text = AttributedString("Needs review")
        text.setNativeEditorInlineComments([
            NativeEditorInlineCommentMark(commentID: "comment-1", isResolved: false)
        ])

        let block = NativeEditorBlock(kind: .paragraph, text: text, alignment: .left)

        #expect(
            NativeEditorMarkdownParser.markdown(from: [block]) ==
                #"<span class="comment-mark" data-comment-id="comment-1">Needs review</span>"#
        )
    }

    @Test func markdownImportPreservesDocmostInlineCommentSpan() throws {
        let markdown = #"Review <span class="comment-mark resolved" data-comment-id="comment-1" "# +
            #"data-resolved>this **copy**</span> today"#
        let block = try #require(
            NativeEditorMarkdownParser.blocks(from: markdown).first
        )

        let comment = NativeEditorInlineCommentMark(commentID: "comment-1", isResolved: true)
        let markedRuns = block.text.runs.filter { $0.nativeEditorInlineComments == [comment] }

        #expect(markedRuns.count == 2)
        let boldRun = try #require(markedRuns.last)
        #expect(String(block.text[boldRun.range].characters) == "copy")
        #expect(boldRun.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)

        let inlineNodes = try #require(NativeEditorDocument(blocks: [block]).proseMirrorDocument.content.first?.content)
        let commentMark = ProseMirrorMark(
            type: "comment",
            attrs: ["commentId": .string("comment-1"), "resolved": .bool(true)]
        )
        #expect(inlineNodes.contains { $0.marks?.contains(commentMark) == true })
    }

    @Test func preservesOverlappingInlineCommentMarks() throws {
        let data = Data("""
        {
          "type": "doc",
          "content": [
            {
              "type": "paragraph",
              "content": [
                {
                  "type": "text",
                  "text": "Overlap",
                  "marks": [
                    {
                      "type": "comment",
                      "attrs": { "commentId": "comment-1", "resolved": false }
                    },
                    {
                      "type": "comment",
                      "attrs": { "commentId": "comment-2", "resolved": true }
                    }
                  ]
                }
              ]
            }
          ]
        }
        """.utf8)

        let document = try NativeEditorDocument(proseMirrorJSONData: data)
        let block = try #require(document.blocks.first)
        let run = try #require(block.text.runs.first)

        #expect(run[NativeEditorCommentIDAttribute.self] == "comment-1")
        #expect(run[NativeEditorCommentResolvedAttribute.self] == false)
        #expect(run[NativeEditorCommentMarksAttribute.self] == [
            NativeEditorInlineCommentMark(commentID: "comment-1", isResolved: false),
            NativeEditorInlineCommentMark(commentID: "comment-2", isResolved: true)
        ])

        let marks = try #require(document.proseMirrorDocument.content.first?.content?.first?.marks)
        #expect(marks.filter { $0.type == "comment" } == [
            ProseMirrorMark(type: "comment", attrs: ["commentId": .string("comment-1"), "resolved": .bool(false)]),
            ProseMirrorMark(type: "comment", attrs: ["commentId": .string("comment-2"), "resolved": .bool(true)])
        ])
    }
}
