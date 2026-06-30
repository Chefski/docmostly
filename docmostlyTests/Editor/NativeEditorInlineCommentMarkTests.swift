import Foundation
import Testing
@testable import docmostly

@MainActor
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

    @Test func markdownImportTreatsExplicitFalseResolvedAttributeAsUnresolved() throws {
        let markdown = #"Review <span class="comment-mark" data-comment-id="comment-1" "# +
            #"data-resolved="false">this copy</span> today"#
        let block = try #require(
            NativeEditorMarkdownParser.blocks(from: markdown).first
        )

        let comment = NativeEditorInlineCommentMark(commentID: "comment-1", isResolved: false)
        let markedRun = try #require(block.text.runs.first { $0.nativeEditorInlineComments == [comment] })
        #expect(String(block.text[markedRun.range].characters) == "this copy")

        let inlineNodes = try #require(NativeEditorDocument(blocks: [block]).proseMirrorDocument.content.first?.content)
        let commentMark = ProseMirrorMark(
            type: "comment",
            attrs: ["commentId": .string("comment-1"), "resolved": .bool(false)]
        )
        #expect(inlineNodes.contains { $0.marks?.contains(commentMark) == true })
    }

    @Test func markdownImportPreservesCommentBodyContainingLiteralSpanText() throws {
        let markdown = #"Review <span class="comment-mark" data-comment-id="comment-1">use `<span>` text</span> today"#
        let block = try #require(
            NativeEditorMarkdownParser.blocks(from: markdown).first
        )

        let comment = NativeEditorInlineCommentMark(commentID: "comment-1", isResolved: false)
        let markedRuns = block.text.runs.filter { $0.nativeEditorInlineComments == [comment] }
        #expect(markedRuns.isEmpty == false)

        let markedText = markedRuns.reduce(into: "") { text, run in
            text += String(block.text[run.range].characters)
        }
        #expect(markedText == "use <span> text")
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

    @Test func preservesInlineCommentMarksOnMentionAtoms() throws {
        let data = Data("""
        {
          "type": "doc",
          "content": [
            {
              "type": "paragraph",
              "content": [
                { "type": "text", "text": "Ask " },
                {
                  "type": "mention",
                  "attrs": {
                    "id": "mention-1",
                    "label": "Taylor",
                    "entityType": "user",
                    "entityId": "user-1"
                  },
                  "marks": [
                    {
                      "type": "comment",
                      "attrs": { "commentId": "comment-1", "resolved": false }
                    }
                  ]
                },
                { "type": "text", "text": " today" }
              ]
            }
          ]
        }
        """.utf8)

        let document = try NativeEditorDocument(proseMirrorJSONData: data)
        let block = try #require(document.blocks.first)
        let mentionRun = try #require(block.text.runs.first { run in
            run[NativeEditorMentionAttribute.self]?.identifier == "mention-1"
        })

        #expect(mentionRun.nativeEditorInlineComments == [
            NativeEditorInlineCommentMark(commentID: "comment-1", isResolved: false)
        ])

        let mentionNode = try #require(
            document.proseMirrorDocument.content.first?.content?.first { $0.type == "mention" }
        )
        #expect(mentionNode.marks == [
            ProseMirrorMark(type: "comment", attrs: ["commentId": .string("comment-1"), "resolved": .bool(false)])
        ])
    }
}
