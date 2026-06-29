import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorInlineCodeMarkdownTests {
    @Test func markdownImportPreservesDoubleBacktickCodeSpans() throws {
        let markdown = "Use ``let `tick` = true`` today"
        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)

        #expect(String(block.text.characters) == "Use let `tick` = true today")

        let inlineNodes = NativeEditorDocument.inlineNodes(from: block.text)
        let codeNode = try #require(inlineNodes.first { $0.text == "let `tick` = true" })
        #expect(codeNode.marks?.contains(ProseMirrorMark(type: "code")) == true)
        #expect(NativeEditorMarkdownParser.markdown(from: [block]) == markdown)
    }

    @Test func markdownExportUsesLongerBacktickRunForCodeContainingDoubleBackticks() throws {
        var text = AttributedString("Use ")
        var code = AttributedString("value `` fence")
        code.inlinePresentationIntent = .code
        text += code
        text += AttributedString(" today")
        let block = NativeEditorBlock(kind: .paragraph, text: text, alignment: .left)

        let markdown = NativeEditorMarkdownParser.markdown(from: [block])

        #expect(markdown == "Use ```value `` fence``` today")

        let importedBlock = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)
        #expect(String(importedBlock.text.characters) == "Use value `` fence today")
        let codeNode = try #require(NativeEditorDocument.inlineNodes(from: importedBlock.text).first {
            $0.text == "value `` fence"
        })
        #expect(codeNode.marks?.contains(ProseMirrorMark(type: "code")) == true)
    }
}
