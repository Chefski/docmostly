import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorStatusMarkdownTests {
    @Test func markdownExportPreservesStatusAtomAsDocmostHTML() {
        var text = AttributedString("Stage ")
        var statusText = AttributedString("Blocked")
        statusText[NativeEditorStatusAttribute.self] = NativeEditorStatusBadge(text: "Blocked", color: "red")
        text += statusText
        text += AttributedString(" now")

        let block = NativeEditorBlock(kind: .paragraph, text: text, alignment: .left)

        #expect(
            NativeEditorMarkdownParser.markdown(from: [block]) ==
                #"Stage <span data-type="status" data-color="red">Blocked</span> now"#
        )
    }

    @Test func markdownImportPreservesDocmostStatusHTMLAsAtom() throws {
        let block = try #require(NativeEditorMarkdownParser.blocks(
            from: #"Stage <span data-type="status" data-color="green">Ship</span> now"#
        ).first)

        let statusRun = try #require(block.text.runs.first { run in
            run[NativeEditorStatusAttribute.self]?.text == "Ship"
        })
        #expect(statusRun[NativeEditorStatusAttribute.self]?.color == "green")

        let inlineNodes = try #require(NativeEditorDocument.node(from: block).content)
        #expect(inlineNodes.map(\.type) == ["text", "status", "text"])
        #expect(inlineNodes[0].text == "Stage ")
        #expect(inlineNodes[2].text == " now")
        #expect(inlineNodes[1].attrs?["text"] == .string("Ship"))
        #expect(inlineNodes[1].attrs?["color"] == .string("green"))
    }

    @Test func markdownImportSkipsMalformedStatusSpanAndPreservesLaterStatusAtom() throws {
        let markdown = #"Stage <span data-type="status" data-color="red">Broken "#
            + #"<span data-type="status" data-color="green">Ship</span> now"#
        let block = try #require(NativeEditorMarkdownParser.blocks(
            from: markdown
        ).first)

        let statusRun = try #require(block.text.runs.first { run in
            run[NativeEditorStatusAttribute.self]?.text == "Ship"
        })
        #expect(statusRun[NativeEditorStatusAttribute.self]?.color == "green")

        let inlineNodes = try #require(NativeEditorDocument.node(from: block).content)
        #expect(inlineNodes.contains { node in
            node.type == "status" &&
                node.attrs?["text"] == .string("Ship") &&
                node.attrs?["color"] == .string("green")
        })
    }

    @Test func markdownImportRecoversFromRepeatedMalformedStatusSpans() throws {
        let malformedSpans = Array(
            repeating: #"<span data-type="status" data-color="red">Broken "#,
            count: 25
        ).joined()
        let block = try #require(NativeEditorMarkdownParser.blocks(
            from: malformedSpans + #"<span data-type="status" data-color="green">Ship</span>"#
        ).first)

        let statusRun = try #require(block.text.runs.first { run in
            run[NativeEditorStatusAttribute.self]?.text == "Ship"
        })
        #expect(statusRun[NativeEditorStatusAttribute.self]?.color == "green")
    }
}
