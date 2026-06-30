import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorCalloutMarkdownTests {
    @Test func markdownImportNormalizesUnknownCalloutFenceStyleToInfo() throws {
        let block = try #require(NativeEditorMarkdownParser.blocks(from: """
        :::strange
        Check migration plan
        :::
        """).first)

        guard case .callout(let callout) = block.kind else {
            Issue.record("Expected fenced callout Markdown to import as a native callout block.")
            return
        }

        #expect(callout.style == "info")
        #expect(block.rawNode?.attrs?["type"] == .string("info"))
        #expect(NativeEditorMarkdownParser.markdown(from: [block]) == """
        :::info
        Check migration plan
        :::
        """)
    }

    @Test func markdownExportNormalizesUnknownNativeCalloutStyleToInfo() {
        let block = NativeEditorBlock(
            kind: .callout(NativeEditorCalloutBlock(
                style: "strange",
                icon: nil,
                previewText: "Check migration plan"
            )),
            text: AttributedString("Check migration plan"),
            alignment: .left
        )

        #expect(NativeEditorMarkdownParser.markdown(from: [block]) == """
        :::info
        Check migration plan
        :::
        """)
    }

    @Test func markdownExportUsesDocmostHTMLForCalloutStylesThatFencesCannotPreserve() {
        let block = NativeEditorBlock(
            kind: .callout(NativeEditorCalloutBlock(
                style: "note",
                icon: nil,
                previewText: "Preserve the note style"
            )),
            text: AttributedString("Preserve the note style"),
            alignment: .left
        )

        #expect(NativeEditorMarkdownParser.markdown(from: [block]) == """
        <div data-type="callout" data-callout-type="note">
        Preserve the note style
        </div>
        """)
    }
}
