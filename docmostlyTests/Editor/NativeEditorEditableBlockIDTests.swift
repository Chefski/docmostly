import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorEditableBlockIDTests {
    @Test func importsDocmostHeadingHTMLWithEditableAttrs() throws {
        let markdown = #"<h2 id="heading-deep-link" data-indent="2" style="text-align: center">Roadmap</h2>"#
        var block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)

        #expect(block.kind == .heading(level: 2))
        #expect(block.isEditable == true)
        #expect(String(block.text.characters) == "Roadmap")
        #expect(block.alignment == .center)
        #expect(block.indentLevel == 2)
        #expect(block.rawNode?.type == "heading")
        #expect(block.rawNode?.attrs?["level"] == .int(2))
        #expect(block.rawNode?.attrs?["id"] == .string("heading-deep-link"))
        #expect(block.rawNode?.attrs?["indent"] == .int(2))
        #expect(block.rawNode?.attrs?["textAlign"] == .string("center"))
        #expect(NativeEditorMarkdownParser.markdown(from: [block]) == markdown)

        block.indentLevel = 4
        #expect(
            NativeEditorMarkdownParser.markdown(from: [block]) ==
                #"<h2 id="heading-deep-link" data-indent="4" style="text-align: center">Roadmap</h2>"#
        )
    }

    @Test func importsDocmostParagraphHTMLWithEditableAttrs() throws {
        let markdown = #"<p id="paragraph-node" data-indent="1" style="text-align: right">Body</p>"#
        var block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)

        #expect(block.kind == .paragraph)
        #expect(block.isEditable == true)
        #expect(String(block.text.characters) == "Body")
        #expect(block.alignment == .right)
        #expect(block.indentLevel == 1)
        #expect(block.rawNode?.type == "paragraph")
        #expect(block.rawNode?.attrs?["id"] == .string("paragraph-node"))
        #expect(block.rawNode?.attrs?["indent"] == .int(1))
        #expect(block.rawNode?.attrs?["textAlign"] == .string("right"))
        #expect(NativeEditorMarkdownParser.markdown(from: [block]) == markdown)

        block.indentLevel = 0
        #expect(
            NativeEditorMarkdownParser.markdown(from: [block]) ==
                #"<p id="paragraph-node" style="text-align: right">Body</p>"#
        )
    }

    @Test func preservesEditableBlockIDsAfterNativeEdits() throws {
        let data = Data("""
        {
          "type": "doc",
          "content": [
            {
              "type": "heading",
              "attrs": { "level": 2, "id": "heading-deep-link", "indent": 2, "textAlign": "center" },
              "content": [{ "type": "text", "text": "Plan" }]
            },
            {
              "type": "paragraph",
              "attrs": { "id": "paragraph-node", "indent": 1 },
              "content": [{ "type": "text", "text": "Body" }]
            }
          ]
        }
        """.utf8)
        var document = try NativeEditorDocument(proseMirrorJSONData: data)

        #expect(document.blocks[0].indentLevel == 2)
        #expect(document.blocks[1].indentLevel == 1)
        document.blocks[0].text = AttributedString("Updated plan")
        document.blocks[0].indentLevel = 3
        document.blocks[1].text = AttributedString("Updated body")
        document.blocks[1].indentLevel = 0

        let encodedData = try document.proseMirrorJSONData()
        let root = try #require(JSONSerialization.jsonObject(with: encodedData) as? [String: Any])
        let content = try #require(root["content"] as? [[String: Any]])
        #expect(content.count == 2)
        let headingNode = try #require(content.first)
        let paragraphNode = try #require(content.dropFirst().first)
        let headingAttrs = try #require(headingNode["attrs"] as? [String: Any])
        let paragraphAttrs = try #require(paragraphNode["attrs"] as? [String: Any])
        let headingContent = try #require(headingNode["content"] as? [[String: Any]])
        let paragraphContent = try #require(paragraphNode["content"] as? [[String: Any]])

        #expect(headingAttrs["id"] as? String == "heading-deep-link")
        #expect(headingAttrs["level"] as? Int == 2)
        #expect(headingAttrs["indent"] as? Int == 3)
        #expect(headingAttrs["textAlign"] as? String == "center")
        #expect(headingContent.first?["text"] as? String == "Updated plan")
        #expect(paragraphAttrs["id"] as? String == "paragraph-node")
        #expect(paragraphAttrs["indent"] == nil)
        #expect(paragraphContent.first?["text"] as? String == "Updated body")
    }

    @Test func encodesStableDocmostIDsForNativeEditableBlocks() throws {
        let paragraphID = try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let headingID = try #require(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let quoteID = try #require(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let listID = try #require(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let document = NativeEditorDocument(blocks: [
            NativeEditorBlock(
                id: paragraphID,
                kind: .paragraph,
                text: AttributedString("Body"),
                alignment: .left
            ),
            NativeEditorBlock(
                id: headingID,
                kind: .heading(level: 2),
                text: AttributedString("Plan"),
                alignment: .left
            ),
            NativeEditorBlock(
                id: quoteID,
                kind: .blockquote,
                text: AttributedString("Quote"),
                alignment: .left
            ),
            NativeEditorBlock(
                id: listID,
                kind: .bulletListItem,
                text: AttributedString("Checklist"),
                alignment: .left
            )
        ])

        let firstEncoding = document.proseMirrorDocument
        let secondEncoding = document.proseMirrorDocument
        let paragraphNode = try #require(firstEncoding.content.first)
        let headingNode = try #require(firstEncoding.content.dropFirst().first)
        let quoteParagraph = try #require(firstEncoding.content.dropFirst(2).first?.content?.first)
        let listParagraph = try #require(
            firstEncoding.content.dropFirst(3).first?.content?.first?.content?.first
        )

        let paragraphNodeID = try expectDocmostNodeID(paragraphNode.attrs?["id"])
        let headingNodeID = try expectDocmostNodeID(headingNode.attrs?["id"])
        let quoteNodeID = try expectDocmostNodeID(quoteParagraph.attrs?["id"])
        let listNodeID = try expectDocmostNodeID(listParagraph.attrs?["id"])

        #expect(headingNode.attrs?["level"] == .int(2))
        #expect(paragraphNodeID != headingNodeID)
        #expect(Set([paragraphNodeID, headingNodeID, quoteNodeID, listNodeID]).count == 4)
        #expect(secondEncoding == firstEncoding)
    }
}

private func expectDocmostNodeID(_ value: ProseMirrorJSONValue?) throws -> String {
    let nodeID = try #require(value?.stringValue)
    #expect(nodeID.count == 12)
    #expect(Set(nodeID).isSubset(of: Set("abcdefghijklmnopqrstuvwxyz")))
    return nodeID
}
