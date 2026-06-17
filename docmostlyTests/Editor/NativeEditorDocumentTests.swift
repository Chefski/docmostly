import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorDocumentTests {
    @Test func decodesDocmostBlocksAndInlineMarks() throws {
        let document = try NativeEditorDocument(proseMirrorJSONData: Self.docmostBlocksFixture)

        #expect(document.blocks.count == 4)
        #expect(document.blocks[0].kind == .heading(level: 2))
        #expect(document.blocks[0].alignment == .center)
        #expect(String(document.blocks[0].text.characters) == "Plan")
        #expect(document.blocks[0].text.runs.first?.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)

        #expect(document.blocks[1].kind == .paragraph)
        let italicRun = try #require(document.blocks[1].text.runs.first)
        #expect(italicRun.inlinePresentationIntent?.contains(.emphasized) == true)

        let linkRun = try #require(document.blocks[1].text.runs.first { run in
            String(document.blocks[1].text.characters[run.range]) == "Docmost"
        })
        #expect(linkRun.link?.absoluteString == "https://docmost.com")

        #expect(document.blocks[2].kind == .bulletListItem)
        #expect(String(document.blocks[2].text.characters) == "First")

        #expect(document.blocks[3].kind == .unsupported(type: "table"))
        #expect(document.blocks[3].isEditable == false)
    }

    @Test func encodesNativeBlocksAsDocmostProseMirrorJSON() throws {
        var intro = AttributedString("Native")
        intro.inlinePresentationIntent = .stronglyEmphasized
        var link = AttributedString(" editor")
        let linkURLString = "https://docmost.com"
        link.link = URL(string: linkURLString)
        intro += link

        let document = NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .heading(level: 1), text: AttributedString("Roadmap"), alignment: .left),
            NativeEditorBlock(kind: .paragraph, text: intro, alignment: .left),
            NativeEditorBlock(kind: .bulletListItem, text: AttributedString("Offline editing"), alignment: .left),
            NativeEditorBlock(kind: .bulletListItem, text: AttributedString("Native toolbar"), alignment: .left)
        ])

        let data = try document.proseMirrorJSONData()
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let content = try #require(root["content"] as? [[String: Any]])

        #expect(root["type"] as? String == "doc")
        #expect(content.count == 3)
        #expect(content[0]["type"] as? String == "heading")
        #expect((content[0]["attrs"] as? [String: Any])?["level"] as? Int == 1)

        let paragraphContent = try #require(content[1]["content"] as? [[String: Any]])
        let boldMarks = try #require(paragraphContent[0]["marks"] as? [[String: Any]])
        #expect(boldMarks.first?["type"] as? String == "bold")

        let linkMarks = try #require(paragraphContent[1]["marks"] as? [[String: Any]])
        #expect(linkMarks.first?["type"] as? String == "link")
        #expect((linkMarks.first?["attrs"] as? [String: Any])?["href"] as? String == linkURLString)

        #expect(content[2]["type"] as? String == "bulletList")
        #expect((content[2]["content"] as? [[String: Any]])?.count == 2)
    }

    private static var docmostBlocksFixture: Data {
        Data("""
        {
          "type": "doc",
          "content": [
            {
              "type": "heading",
              "attrs": { "level": 2, "textAlign": "center" },
              "content": [
                { "type": "text", "text": "Plan", "marks": [{ "type": "bold" }] }
              ]
            },
            {
              "type": "paragraph",
              "content": [
                { "type": "text", "text": "Visit ", "marks": [{ "type": "italic" }] },
                {
                  "type": "text",
                  "text": "Docmost",
                  "marks": [{ "type": "link", "attrs": { "href": "https://docmost.com" } }]
                }
              ]
            },
            {
              "type": "bulletList",
              "content": [
                {
                  "type": "listItem",
                  "content": [
                    { "type": "paragraph", "content": [{ "type": "text", "text": "First" }] }
                  ]
                }
              ]
            },
            { "type": "table", "content": [] }
          ]
        }
        """.utf8)
    }
}
