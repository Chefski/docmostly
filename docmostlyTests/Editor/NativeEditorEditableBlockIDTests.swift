import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorEditableBlockIDTests {
    @Test func preservesEditableBlockIDsAfterNativeEdits() throws {
        let data = Data("""
        {
          "type": "doc",
          "content": [
            {
              "type": "heading",
              "attrs": { "level": 2, "id": "heading-deep-link", "textAlign": "center" },
              "content": [{ "type": "text", "text": "Plan" }]
            },
            {
              "type": "paragraph",
              "attrs": { "id": "paragraph-node" },
              "content": [{ "type": "text", "text": "Body" }]
            }
          ]
        }
        """.utf8)
        var document = try NativeEditorDocument(proseMirrorJSONData: data)

        document.blocks[0].text = AttributedString("Updated plan")
        document.blocks[1].text = AttributedString("Updated body")

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
        #expect(headingAttrs["textAlign"] as? String == "center")
        #expect(headingContent.first?["text"] as? String == "Updated plan")
        #expect(paragraphAttrs["id"] as? String == "paragraph-node")
        #expect(paragraphContent.first?["text"] as? String == "Updated body")
    }
}
