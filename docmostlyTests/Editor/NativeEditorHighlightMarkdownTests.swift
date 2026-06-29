import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeEditorHighlightMarkdownTests {
    @Test func markdownExportPreservesDocmostHighlightMarkAsHTML() {
        var text = AttributedString("Review ")
        var highlighted = AttributedString("important")
        highlighted[NativeEditorHighlightColorAttribute.self] = "#FEF3C7"
        highlighted[NativeEditorHighlightColorNameAttribute.self] = "yellow"
        highlighted.backgroundColor = Color(docmostlyHex: "#FEF3C7")
        text += highlighted
        text += AttributedString(" today")

        let block = NativeEditorBlock(kind: .paragraph, text: text, alignment: .left)
        let expectedMarkdown = ##"Review <mark data-color="#FEF3C7" "## +
            ##"style="background-color: #FEF3C7; color: inherit" "## +
            ##"data-highlight-color-name="yellow">important</mark> today"##

        #expect(NativeEditorMarkdownParser.markdown(from: [block]) == expectedMarkdown)
    }

    @Test func markdownImportPreservesDocmostHighlightMarkAsProseMirrorMark() throws {
        let markdown = ##"Review <mark data-color="#DCFCE7" data-highlight-color-name="green">"## +
            "important **copy**</mark> today"
        let block = try #require(NativeEditorMarkdownParser.blocks(
            from: markdown
        ).first)

        let highlightedRuns = block.text.runs.filter { run in
            run[NativeEditorHighlightColorAttribute.self] == "#DCFCE7" &&
                run[NativeEditorHighlightColorNameAttribute.self] == "green"
        }
        #expect(highlightedRuns.count == 2)

        let boldRun = try #require(highlightedRuns.last)
        #expect(String(block.text[boldRun.range].characters) == "copy")
        #expect(boldRun.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)

        let inlineNodes = try #require(NativeEditorDocument.node(from: block).content)
        let highlightMark = ProseMirrorMark(
            type: "highlight",
            attrs: ["color": .string("#DCFCE7"), "colorName": .string("green")]
        )
        #expect(inlineNodes.contains { $0.marks?.contains(highlightMark) == true })
    }

    @Test func markdownImportIgnoresHighlightHTMLInsideCodeSpans() throws {
        let markdown = ##"Keep `<mark data-color="#FEF3C7">literal</mark>` then "## +
            ##"<mark data-color="#DCFCE7" data-highlight-color-name="green">real</mark>"##
        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)

        let codeRun = try #require(block.text.runs.first { run in
            String(block.text[run.range].characters) == ##"<mark data-color="#FEF3C7">literal</mark>"##
        })
        #expect(codeRun.inlinePresentationIntent?.contains(.code) == true)
        #expect(codeRun[NativeEditorHighlightColorAttribute.self] == nil)

        let highlightRun = try #require(block.text.runs.first { run in
            String(block.text[run.range].characters) == "real"
        })
        #expect(highlightRun[NativeEditorHighlightColorAttribute.self] == "#DCFCE7")
        #expect(highlightRun[NativeEditorHighlightColorNameAttribute.self] == "green")
    }
}
