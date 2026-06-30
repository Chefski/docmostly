import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeEditorScriptUnderlineMarkdownTests {
    @Test func markdownExportPreservesDocmostUnderlineAndScriptMarksAsHTML() {
        let block = NativeEditorBlock(
            kind: .paragraph,
            text: scriptUnderlineFixtureText(),
            alignment: .left
        )

        #expect(
            NativeEditorMarkdownParser.markdown(from: [block]) ==
                "Use <u>underline</u>, x<sup>2</sup>, and H<sub>2</sub>O"
        )
    }

    @Test func markdownImportPreservesDocmostUnderlineAndScriptMarksAsProseMirrorMarks() throws {
        let markdown = "Use <u>underline **now**</u>, x<sup>2</sup>, and H<sub>2</sub>O"
        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)

        let underlinedRuns = block.text.runs.filter { $0.underlineStyle == .single }
        #expect(underlinedRuns.count == 2)

        let boldUnderlinedRun = try #require(underlinedRuns.last)
        #expect(String(block.text[boldUnderlinedRun.range].characters) == "now")
        #expect(boldUnderlinedRun.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)

        let superscriptRun = try #require(run(in: block.text, matching: "2", baselineOffset: 4))
        #expect(String(block.text[superscriptRun.range].characters) == "2")

        let subscriptRun = try #require(run(in: block.text, matching: "2", baselineOffset: -4))
        #expect(String(block.text[subscriptRun.range].characters) == "2")

        let inlineNodes = try #require(NativeEditorDocument.node(from: block).content)
        #expect(inlineNodes.contains { $0.marks?.contains(ProseMirrorMark(type: "underline")) == true })
        #expect(inlineNodes.contains { $0.marks?.contains(ProseMirrorMark(type: "superscript")) == true })
        #expect(inlineNodes.contains { $0.marks?.contains(ProseMirrorMark(type: "subscript")) == true })
    }

    private func scriptUnderlineFixtureText() -> AttributedString {
        var text = AttributedString("Use ")

        var underline = AttributedString("underline")
        underline.underlineStyle = .single
        text += underline

        text += AttributedString(", x")

        var superscript = AttributedString("2")
        superscript.baselineOffset = 4
        text += superscript

        text += AttributedString(", and H")

        var subscriptText = AttributedString("2")
        subscriptText.baselineOffset = -4
        text += subscriptText

        text += AttributedString("O")
        return text
    }

    private func run(
        in text: AttributedString,
        matching value: String,
        baselineOffset: Double
    ) -> AttributedString.Runs.Run? {
        text.runs.first { run in
            String(text[run.range].characters) == value && run.baselineOffset == baselineOffset
        }
    }
}
