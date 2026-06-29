import Foundation
import Testing
@testable import docmostly

struct NativeEditorListFidelityTests {
    @Test func editingListItemPreservesAdditionalDocmostListItemContent() throws {
        let original = try JSONDecoder().decode(
            ProseMirrorDocument.self,
            from: Data("""
            {
              "type": "doc",
              "content": [
                {
                  "type": "bulletList",
                  "content": [
                    {
                      "type": "listItem",
                      "content": [
                        {
                          "type": "paragraph",
                          "content": [{ "type": "text", "text": "Launch checklist" }]
                        },
                        {
                          "type": "paragraph",
                          "content": [{ "type": "text", "text": "Keep rollout notes attached" }]
                        }
                      ]
                    }
                  ]
                }
              ]
            }
            """.utf8)
        )
        var document = NativeEditorDocument(proseMirrorDocument: original)

        #expect(document.blocks.count == 1)
        #expect(document.proseMirrorDocument == original)

        document.blocks[0].text = AttributedString("Release checklist")

        let listItem = try #require(document.proseMirrorDocument.content.first?.content?.first)
        let paragraphs = try #require(listItem.content)
        #expect(paragraphs.count == 2)
        #expect(paragraphs[0].content?.first?.text == "Release checklist")
        #expect(paragraphs[1].content?.first?.text == "Keep rollout notes attached")
    }

    @Test func editingListItemPreservesAdditionalContentAndNestedLists() throws {
        let original = try JSONDecoder().decode(
            ProseMirrorDocument.self,
            from: Data("""
            {
              "type": "doc",
              "content": [
                {
                  "type": "bulletList",
                  "content": [
                    {
                      "type": "listItem",
                      "content": [
                        {
                          "type": "paragraph",
                          "content": [{ "type": "text", "text": "Parent" }]
                        },
                        {
                          "type": "paragraph",
                          "content": [{ "type": "text", "text": "Context" }]
                        },
                        {
                          "type": "taskList",
                          "content": [
                            {
                              "type": "taskItem",
                              "attrs": { "checked": true },
                              "content": [
                                {
                                  "type": "paragraph",
                                  "content": [{ "type": "text", "text": "Child task" }]
                                }
                              ]
                            }
                          ]
                        }
                      ]
                    }
                  ]
                }
              ]
            }
            """.utf8)
        )
        var document = NativeEditorDocument(proseMirrorDocument: original)

        #expect(document.blocks.count == 2)
        document.blocks[0].text = AttributedString("Updated parent")
        document.blocks[1].text = AttributedString("Updated child task")

        let listItem = try #require(document.proseMirrorDocument.content.first?.content?.first)
        let content = try #require(listItem.content)
        #expect(content.count == 3)
        #expect(content[0].content?.first?.text == "Updated parent")
        #expect(content[1].content?.first?.text == "Context")
        #expect(content[2].type == "taskList")
        #expect(content[2].content?.first?.content?.first?.content?.first?.text == "Updated child task")
    }
}
