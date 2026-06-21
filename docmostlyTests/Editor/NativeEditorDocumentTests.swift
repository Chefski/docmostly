import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeEditorDocumentTests {
    @Test func decodesDocmostBlocksAndInlineMarks() throws {
        let document = try NativeEditorDocument(
            proseMirrorJSONData: NativeEditorBasicFixtures.docmostBlocks
        )

        #expect(document.blocks.count == 4)
        #expect(document.blocks[0].kind == .heading(level: 2))
        #expect(document.blocks[0].alignment == .center)
        #expect(String(document.blocks[0].text.characters) == "Plan")
        #expect(document.blocks[0].text.runs.first?.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)

        #expect(document.blocks[1].kind == .paragraph)
        let italicRun = try #require(document.blocks[1].text.runs.first)
        #expect(italicRun.inlinePresentationIntent?.contains(.emphasized) == true)

        let linkRun = try #require(document.blocks[1].text.runs.first { run in
            String(document.blocks[1].text.characters[run.range]) == "Docmost"
        })
        #expect(linkRun.link?.absoluteString == "https://docmost.com")

        #expect(document.blocks[2].kind == .bulletListItem)
        #expect(String(document.blocks[2].text.characters) == "First")

        guard case .table(let table) = document.blocks[3].kind else {
            Issue.record("Expected table block")
            return
        }
        #expect(table.rows.isEmpty)
        #expect(document.blocks[3].isEditable == false)
    }

    @Test func encodesNativeBlocksAsDocmostProseMirrorJSON() throws {
        var intro = AttributedString("Native")
        intro.inlinePresentationIntent = .stronglyEmphasized
        var link = AttributedString(" editor")
        let linkURLString = "https://docmost.com"
        link.link = URL(string: linkURLString)
        intro += link

        let document = NativeEditorDocument(blocks: [
            NativeEditorBlock(kind: .heading(level: 1), text: AttributedString("Roadmap"), alignment: .left),
            NativeEditorBlock(kind: .paragraph, text: intro, alignment: .left),
            NativeEditorBlock(kind: .bulletListItem, text: AttributedString("Offline editing"), alignment: .left),
            NativeEditorBlock(kind: .bulletListItem, text: AttributedString("Native toolbar"), alignment: .left)
        ])

        let data = try document.proseMirrorJSONData()
        let root = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let content = try #require(root["content"] as? [[String: Any]])

        #expect(root["type"] as? String == "doc")
        #expect(content.count == 3)
        #expect(content[0]["type"] as? String == "heading")
        #expect((content[0]["attrs"] as? [String: Any])?["level"] as? Int == 1)

        let paragraphContent = try #require(content[1]["content"] as? [[String: Any]])
        let boldMarks = try #require(paragraphContent[0]["marks"] as? [[String: Any]])
        #expect(boldMarks.first?["type"] as? String == "bold")

        let linkMarks = try #require(paragraphContent[1]["marks"] as? [[String: Any]])
        #expect(linkMarks.first?["type"] as? String == "link")
        #expect((linkMarks.first?["attrs"] as? [String: Any])?["href"] as? String == linkURLString)

        #expect(content[2]["type"] as? String == "bulletList")
        #expect((content[2]["content"] as? [[String: Any]])?.count == 2)
    }

    @Test func decodesRichMediaAndFileBlocks() throws {
        let blocks = try richBlocks()

        guard case .table(let table) = blocks[0].kind else {
            Issue.record("Expected table block")
            return
        }
        #expect(table.rows.count == 2)
        #expect(table.rows[0].cells.map(\.plainText) == ["Feature", "Status"])
        #expect(table.columnWidth(at: 0) == 210)
        #expect(table.columnWidth(at: 1) == 240)

        guard case .image(let image) = blocks[1].kind else {
            Issue.record("Expected image block")
            return
        }
        #expect(image.source == "/files/image.png")
        #expect(image.alternativeText == "Architecture")

        guard case .video(let video) = blocks[2].kind else {
            Issue.record("Expected video block")
            return
        }
        #expect(video.attachmentID == "video-1")
        try expectAudioPDFAndAttachmentBlocks(blocks)
    }

    @Test func decodesRichStructuralBlocks() throws {
        let blocks = try richBlocks()

        guard case .callout(let callout) = blocks[6].kind else {
            Issue.record("Expected callout block")
            return
        }
        #expect(callout.style == "warning")
        #expect(callout.previewText == "Check migration plan")

        guard case .details(let details) = blocks[7].kind else {
            Issue.record("Expected details block")
            return
        }
        #expect(details.summary == "Release checklist")
        #expect(details.isOpen == true)

        #expect(blocks[8].kind == .pageBreak)
        #expect(blocks[9].kind == .divider)
        try expectColumnsAndSyncedBlocks(blocks)
    }

    @Test func decodesRichEmbedDiagramAndMathBlocks() throws {
        let blocks = try richBlocks()

        guard case .embed(let embed) = blocks[14].kind else {
            Issue.record("Expected embed block")
            return
        }
        #expect(embed.provider == "YouTube")

        guard case .drawio(let drawio) = blocks[15].kind else {
            Issue.record("Expected Draw.io block")
            return
        }
        #expect(drawio.title == "Flow")

        guard case .excalidraw(let excalidraw) = blocks[16].kind else {
            Issue.record("Expected Excalidraw block")
            return
        }
        #expect(excalidraw.attachmentID == "exc-1")
        try expectMathAndMermaidBlocks(blocks)
    }

    @Test func decodesNestedListIndentationAndReencodesNestedLists() throws {
        let original = try JSONDecoder().decode(
            ProseMirrorDocument.self,
            from: NativeEditorNestedListFixtures.nestedBulletList
        )
        let document = NativeEditorDocument(proseMirrorDocument: original)

        #expect(document.blocks.count == 2)
        #expect(document.blocks[0].kind == .bulletListItem)
        #expect(document.blocks[0].indentLevel == 0)
        #expect(String(document.blocks[0].text.characters) == "Parent")
        #expect(document.blocks[1].kind == .bulletListItem)
        #expect(document.blocks[1].indentLevel == 1)
        #expect(String(document.blocks[1].text.characters) == "Child")
        #expect(document.proseMirrorDocument == original)
    }

    @Test func rejectsDeeplyNestedProseMirrorJSON() throws {
        do {
            _ = try JSONDecoder().decode(
                ProseMirrorDocument.self,
                from: deeplyNestedDocumentData(depth: 180)
            )
            Issue.record("Expected deeply nested ProseMirror JSON to be rejected")
        } catch {
        }
    }

    @Test func outOfRangeNumericAttributesDoNotTrapNativeDecoding() throws {
        let data = Data("""
        {
          "type": "doc",
          "content": [
            {
              "type": "heading",
              "attrs": { "level": 9223372036854775808 },
              "content": [{ "type": "text", "text": "Huge" }]
            }
          ]
        }
        """.utf8)

        let document = try NativeEditorDocument(proseMirrorJSONData: data)

        #expect(document.blocks.first?.kind == .heading(level: 1))
    }

    @Test func capsDecodedTableDimensions() {
        let oversizedRow = ProseMirrorNode(
            type: "tableRow",
            content: (0..<(NativeEditorTable.maximumColumnCount + 5)).map { index in
                ProseMirrorNode(
                    type: "tableCell",
                    content: [
                        ProseMirrorNode(
                            type: "paragraph",
                            content: [ProseMirrorNode(type: "text", text: "C\(index)")]
                        )
                    ]
                )
            }
        )
        let tableNode = ProseMirrorNode(
            type: "table",
            content: Array(repeating: oversizedRow, count: NativeEditorTable.maximumRowCount + 5)
        )
        let document = NativeEditorDocument(proseMirrorDocument: ProseMirrorDocument(content: [tableNode]))

        guard case .table(let table) = document.blocks.first?.kind else {
            Issue.record("Expected table block")
            return
        }
        #expect(table.rows.count == NativeEditorTable.maximumRowCount)
        #expect(table.columnCount == NativeEditorTable.maximumColumnCount)
    }

    @Test func capsMarkdownTableDimensions() {
        let header = "| " + (0..<(NativeEditorTable.maximumColumnCount + 5))
            .map { "H\($0)" }
            .joined(separator: " | ") + " |"
        let separator = "| " + Array(repeating: "---", count: NativeEditorTable.maximumColumnCount + 5)
            .joined(separator: " | ") + " |"
        let row = "| " + (0..<(NativeEditorTable.maximumColumnCount + 5))
            .map { "C\($0)" }
            .joined(separator: " | ") + " |"
        let markdown = ([header, separator] + Array(repeating: row, count: NativeEditorTable.maximumRowCount + 5))
            .joined(separator: "\n")
        let blocks = NativeEditorMarkdownParser.blocks(from: markdown)

        guard case .table(let table) = blocks.first?.kind else {
            Issue.record("Expected table block")
            return
        }
        #expect(table.rows.count == NativeEditorTable.maximumRowCount)
        #expect(table.columnCount == NativeEditorTable.maximumColumnCount)
    }

    @Test func roundTripsRichDocmostBlocksWithoutDroppingAttributes() throws {
        let original = try JSONDecoder().decode(
            ProseMirrorDocument.self,
            from: NativeEditorRichBlockFixtures.richBlocks
        )
        let document = NativeEditorDocument(proseMirrorDocument: original)

        #expect(document.proseMirrorDocument == original)
    }

    @Test func decodesInlineDocmostFormattingAndAtomNodes() throws {
        let original = try JSONDecoder().decode(
            ProseMirrorDocument.self,
            from: NativeEditorInlineFixtures.richInline
        )
        let document = try NativeEditorDocument(
            proseMirrorJSONData: NativeEditorInlineFixtures.richInline
        )
        let block = try #require(document.blocks.first)

        #expect(block.isEditable == true)
        #expect(block.inlineContent == nil)

        let styledRun = try run(containing: "Styled", in: block.text)
        #expect(styledRun.underlineStyle != nil)
        #expect(styledRun[NativeEditorHighlightColorAttribute.self] == "#faf594")
        #expect(styledRun[NativeEditorHighlightColorNameAttribute.self] == "yellow")
        #expect(styledRun[NativeEditorTextColorAttribute.self] == "#2563EB")
        #expect(styledRun[NativeEditorCommentIDAttribute.self] == "comment-1")
        #expect(styledRun[NativeEditorCommentResolvedAttribute.self] == false)

        let mentionRun = try run(containing: "Roadmap", in: block.text)
        #expect(mentionRun[NativeEditorMentionAttribute.self]?.label == "Roadmap")
        #expect(mentionRun[NativeEditorMentionAttribute.self]?.entityType == "page")
        #expect(mentionRun[NativeEditorMentionAttribute.self]?.slugID == "roadmap-abc")

        let statusRun = try run(containing: "Ship", in: block.text)
        #expect(statusRun[NativeEditorStatusAttribute.self]?.text == "Ship")
        #expect(statusRun[NativeEditorStatusAttribute.self]?.color == "green")

        let mathRun = try run(containing: "x^2", in: block.text)
        #expect(mathRun[NativeEditorMathInlineAttribute.self]?.text == "x^2")
        #expect(document.proseMirrorDocument == original)
    }

    private func deeplyNestedDocumentData(depth: Int) -> Data {
        var node = #"{"type":"text","text":"Leaf"}"#
        for _ in 0..<depth {
            node = #"{"type":"paragraph","content":["# + node + #"]}"#
        }
        let document = #"{"type":"doc","content":["# + node + #"]}"#
        return Data(document.utf8)
    }

    private func richBlocks() throws -> [NativeEditorBlock] {
        let document = try NativeEditorDocument(
            proseMirrorJSONData: NativeEditorRichBlockFixtures.richBlocks
        )

        #expect(document.blocks.count == 19)
        return document.blocks
    }

    private func expectAudioPDFAndAttachmentBlocks(_ blocks: [NativeEditorBlock]) throws {
        guard case .audio(let audio) = blocks[3].kind else {
            Issue.record("Expected audio block")
            return
        }
        #expect(audio.sizeInBytes == 1024)

        guard case .pdf(let pdf) = blocks[4].kind else {
            Issue.record("Expected PDF block")
            return
        }
        #expect(pdf.name == "Spec.pdf")

        guard case .attachment(let attachment) = blocks[5].kind else {
            Issue.record("Expected attachment block")
            return
        }
        #expect(attachment.mimeType == "application/zip")
    }

    private func expectColumnsAndSyncedBlocks(_ blocks: [NativeEditorBlock]) throws {
        guard case .columns(let columns) = blocks[10].kind else {
            Issue.record("Expected columns block")
            return
        }
        #expect(columns.layout == "two_equal")
        #expect(columns.columnCount == 2)

        #expect(blocks[11].kind == .subpages)

        guard case .transclusionSource(let source) = blocks[12].kind else {
            Issue.record("Expected transclusion source")
            return
        }
        #expect(source.identifier == "sync-1")

        guard case .transclusionReference(let reference) = blocks[13].kind else {
            Issue.record("Expected transclusion reference")
            return
        }
        #expect(reference.sourcePageID == "page-1")
        #expect(reference.transclusionID == "sync-1")
    }

    private func expectMathAndMermaidBlocks(_ blocks: [NativeEditorBlock]) throws {
        guard case .mathBlock(let math) = blocks[17].kind else {
            Issue.record("Expected math block")
            return
        }
        #expect(math.text == "E = mc^2")

        guard case .codeBlock(let language) = blocks[18].kind else {
            Issue.record("Expected Mermaid code block")
            return
        }
        #expect(language == "mermaid")
    }

    private func run(
        containing text: String,
        in attributedText: AttributedString
    ) throws -> AttributedString.Runs.Run {
        try #require(attributedText.runs.first { run in
            String(attributedText[run.range].characters).contains(text)
        })
    }
}
