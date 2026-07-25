import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeEditorHeadingMarkdownTests {
    @Test func boldHeadingRoundTripsThroughProseMirror() throws {
        let source = ProseMirrorNode(
            type: "heading",
            attrs: ["level": .int(2)],
            content: [
                ProseMirrorNode(type: "text", text: "Release "),
                ProseMirrorNode(
                    type: "text",
                    marks: [ProseMirrorMark(type: "bold")],
                    text: "today"
                )
            ]
        )

        let block = try #require(NativeEditorDocument.blocks(from: source).first)
        let boldRun = try #require(block.text.runs.last)

        #expect(block.kind == .heading(level: 2))
        #expect(String(block.text[boldRun.range].characters) == "today")
        #expect(boldRun.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
        let encoded = NativeEditorDocument.node(from: block)
        #expect(encoded.type == "heading")
        #expect(encoded.attrs?["level"] == .int(2))
        #expect(encoded.attrs?["id"]?.stringValue?.isEmpty == false)
        #expect(encoded.content == source.content)
    }

    @Test func markdownImportPreservesDeepHeadingLevels() throws {
        let markdown = """
        #### Deep section
        ##### Deep subsection
        ###### Deep detail
        """
        let blocks = NativeEditorMarkdownParser.blocks(from: markdown)

        try #require(blocks.count == 3)
        #expect(blocks[0].kind == .heading(level: 4))
        #expect(blocks[1].kind == .heading(level: 5))
        #expect(blocks[2].kind == .heading(level: 6))
        #expect(NativeEditorMarkdownParser.markdown(from: blocks) == markdown)
    }

    @Test func previewFormatterAppliesAFontOnlyToStrongHeadingRuns() throws {
        var source = AttributedString("Release today")
        let strongRange = try #require(source.range(of: "today"))
        source[strongRange].inlinePresentationIntent = .stronglyEmphasized

        let formatted = NativeEditorPreviewTextFormatter.text(source, for: .heading(level: 2))
        let releaseRun = try #require(formatted.runs.first)
        let strongRun = try #require(formatted.runs.last)

        #expect(releaseRun.font == nil)
        #expect(strongRun.font != nil)
    }
}
