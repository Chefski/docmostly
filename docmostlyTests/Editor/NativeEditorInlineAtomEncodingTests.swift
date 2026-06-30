import Foundation
import Testing
@testable import docmostly

struct NativeEditorInlineAtomEncodingTests {
    @Test func emptyDocmostInlineMathAtomSurvivesNativeRoundTrip() throws {
        let paragraph = ProseMirrorNode(
            type: "paragraph",
            content: [
                ProseMirrorNode(type: "mathInline", attrs: ["text": .string("")])
            ]
        )

        let block = try #require(NativeEditorDocument.blocks(from: paragraph).first)
        let mathRun = try #require(block.text.runs.first { run in
            run[NativeEditorMathInlineAttribute.self] != nil
        })

        let inlineNodes = try #require(NativeEditorDocument.node(from: block).content)
        #expect(String(block.text[mathRun.range].characters) == "SET EQUATION")
        #expect(inlineNodes.map(\.type) == ["mathInline"])
        #expect(inlineNodes.first?.attrs?["text"] == .string(""))
    }

    @Test func encodesInlineAtomRunsWithoutSwallowingSurroundingText() {
        let math = NativeEditorMathInline(text: "E = mc^2")
        var text = AttributedString("Formula E = mc^2 today")
        text[NativeEditorMathInlineAttribute.self] = math
        text.inlinePresentationIntent = .code

        let block = NativeEditorBlock(kind: .paragraph, text: text, alignment: .left)
        let document = NativeEditorDocument(blocks: [block])
        let inlineNodes = document.proseMirrorDocument.content.first?.content ?? []

        #expect(inlineNodes.map(\.type) == ["text", "mathInline", "text"])
        #expect(inlineNodes[0].text == "Formula ")
        #expect(inlineNodes[0].marks == nil)
        #expect(inlineNodes[1].attrs?["text"] == .string("E = mc^2"))
        #expect(inlineNodes[2].text == " today")
        #expect(inlineNodes[2].marks == nil)
    }
}
