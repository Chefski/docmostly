import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorMarkdownImportTests {
    @Test func markdownLinksImportAsNativeMediaAndAttachmentBlocks() throws {
        let blocks = NativeEditorMarkdownParser.blocks(from: """
        [Launch demo.mp4](/files/demo.mp4)
        [Release audio.m4a](/files/audio.m4a)
        [Spec.pdf](/files/spec.pdf)
        [Archive.zip](/files/archive.zip)
        """)

        #expect(blocks.count == 4)

        guard case .video(let video) = blocks[0].kind else {
            Issue.record("Expected video Markdown link to import as a native video block.")
            return
        }
        #expect(video.source == "/files/demo.mp4")
        #expect(video.title == "Launch demo.mp4")
        #expect(blocks[0].rawNode?.type == "video")

        guard case .audio(let audio) = blocks[1].kind else {
            Issue.record("Expected audio Markdown link to import as a native audio block.")
            return
        }
        #expect(audio.source == "/files/audio.m4a")
        #expect(audio.title == "Release audio.m4a")
        #expect(blocks[1].rawNode?.type == "audio")

        guard case .pdf(let pdf) = blocks[2].kind else {
            Issue.record("Expected PDF Markdown link to import as a native PDF block.")
            return
        }
        #expect(pdf.source == "/files/spec.pdf")
        #expect(pdf.name == "Spec.pdf")
        #expect(blocks[2].rawNode?.type == "pdf")

        guard case .attachment(let attachment) = blocks[3].kind else {
            Issue.record("Expected file Markdown link to import as a native attachment block.")
            return
        }
        #expect(attachment.url == "/files/archive.zip")
        #expect(attachment.name == "Archive.zip")
        #expect(blocks[3].rawNode?.type == "attachment")
    }

    @Test func genericMarkdownLinksRemainEditableParagraphText() throws {
        let block = try #require(NativeEditorMarkdownParser.blocks(from: "[Example](https://example.com)").first)

        #expect(block.kind == .paragraph)
        #expect(String(block.text.characters) == "Example")
    }
}
