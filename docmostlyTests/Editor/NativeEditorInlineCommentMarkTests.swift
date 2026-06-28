import Foundation
import Testing
@testable import docmostly

struct NativeEditorInlineCommentMarkTests {
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
