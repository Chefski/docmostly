import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeEditorTextColorMarkdownTests {
    @Test func markdownExportPreservesDocmostTextColorMarkAsHTML() {
        var text = AttributedString("Review ")
        var colored = AttributedString("important")
        colored[NativeEditorTextColorAttribute.self] = "#2563EB"
        colored.foregroundColor = Color(docmostlyHex: "#2563EB")
        text += colored
        text += AttributedString(" today")

        let block = NativeEditorBlock(kind: .paragraph, text: text, alignment: .left)

        #expect(
            NativeEditorMarkdownParser.markdown(from: [block]) ==
                ##"Review <span style="color: #2563EB">important</span> today"##
        )
    }

    @Test func markdownImportPreservesDocmostTextColorSpanAsProseMirrorMark() throws {
        let markdown = ##"Review <span style="color: #2563EB">important **copy**</span> today"##
        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)

        let coloredRuns = block.text.runs.filter { run in
            run[NativeEditorTextColorAttribute.self] == "#2563EB"
        }
        #expect(coloredRuns.count == 2)

        let boldRun = try #require(coloredRuns.last)
        #expect(String(block.text[boldRun.range].characters) == "copy")
        #expect(boldRun.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)

        let inlineNodes = try #require(NativeEditorDocument.node(from: block).content)
        let textColorMark = ProseMirrorMark(
            type: "textStyle",
            attrs: ["color": .string("#2563EB")]
        )
        #expect(inlineNodes.contains { $0.marks?.contains(textColorMark) == true })
    }
}
