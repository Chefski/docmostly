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

    @Test func markdownImportIgnoresTextColorHTMLInsideCodeSpans() throws {
        let markdown = ##"Keep `<span style="color: #DC2626">literal</span>` then "## +
            ##"<span style="color: #2563EB">real</span>"##
        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)

        let codeRun = try #require(block.text.runs.first { run in
            String(block.text[run.range].characters) == #"<span style="color: #DC2626">literal</span>"#
        })
        #expect(codeRun.inlinePresentationIntent?.contains(.code) == true)
        #expect(codeRun[NativeEditorTextColorAttribute.self] == nil)

        let coloredRun = try #require(block.text.runs.first { run in
            String(block.text[run.range].characters) == "real"
        })
        #expect(coloredRun[NativeEditorTextColorAttribute.self] == "#2563EB")
    }

    @Test func markdownImportPreservesNestedTextColorSpans() throws {
        let markdown = ##"<span style="color: #111827">outer "## +
            ##"<span style="color: #2563EB">inner</span> tail</span>"##
        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)

        let outerRun = try #require(block.text.runs.first { run in
            String(block.text[run.range].characters) == "outer "
        })
        let innerRun = try #require(block.text.runs.first { run in
            String(block.text[run.range].characters) == "inner"
        })
        let tailRun = try #require(block.text.runs.first { run in
            String(block.text[run.range].characters) == " tail"
        })

        #expect(outerRun[NativeEditorTextColorAttribute.self] == "#111827")
        #expect(innerRun[NativeEditorTextColorAttribute.self] == "#2563EB")
        #expect(tailRun[NativeEditorTextColorAttribute.self] == "#111827")
    }
}
