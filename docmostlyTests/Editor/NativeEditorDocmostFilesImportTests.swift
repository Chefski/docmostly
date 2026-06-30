import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorDocmostFilesImportTests {
    @Test func imageMarkdownWithTrailingTextDoesNotDropTextDuringImport() throws {
        let blocks = NativeEditorMarkdownParser.blocks(from: "![Hero](/files/image-1/Hero.png) ships today")

        try #require(blocks.count == 2)
        guard case .image(let image) = blocks[0].kind else {
            Issue.record("Expected leading image Markdown to stay as a native image block.")
            return
        }
        #expect(image.source == "/files/image-1/Hero.png")
        #expect(image.alternativeText == "Hero")
        #expect(image.attachmentID == "image-1")
        #expect(blocks[1].kind == .paragraph)
        #expect(String(blocks[1].text.characters) == "ships today")
    }

    @Test func importsDocmostFilesShorthandURLsWithAttachmentIDs() throws {
        let markdown = """
        ![Hero](/files/image-1/Hero.png)
        [Demo.mp4](/files/video-1/Demo.mp4)
        [Briefing.m4a](/files/audio-1/Briefing.m4a)
        [Spec.pdf](/files/pdf-1/Spec.pdf)
        [Archive.zip](/files/file-1/Archive.zip)
        """
        let blocks = NativeEditorMarkdownParser.blocks(from: markdown)

        try #require(blocks.count == 5)
        guard case .image(let image) = blocks[0].kind else {
            Issue.record("Expected /files image URL to import as a native image block.")
            return
        }
        guard case .video(let video) = blocks[1].kind else {
            Issue.record("Expected /files video URL to import as a native video block.")
            return
        }
        guard case .audio(let audio) = blocks[2].kind else {
            Issue.record("Expected /files audio URL to import as a native audio block.")
            return
        }
        guard case .pdf(let pdf) = blocks[3].kind else {
            Issue.record("Expected /files PDF URL to import as a native PDF block.")
            return
        }
        guard case .attachment(let attachment) = blocks[4].kind else {
            Issue.record("Expected /files attachment URL to import as a native attachment block.")
            return
        }

        #expect(image.attachmentID == "image-1")
        #expect(video.attachmentID == "video-1")
        #expect(audio.attachmentID == "audio-1")
        #expect(pdf.attachmentID == "pdf-1")
        #expect(attachment.attachmentID == "file-1")
        #expect(blocks[0].rawNode?.attrs?["attachmentId"] == .string("image-1"))
        #expect(blocks[1].rawNode?.attrs?["attachmentId"] == .string("video-1"))
        #expect(blocks[2].rawNode?.attrs?["attachmentId"] == .string("audio-1"))
        #expect(blocks[3].rawNode?.attrs?["attachmentId"] == .string("pdf-1"))
        #expect(blocks[4].rawNode?.attrs?["attachmentId"] == .string("file-1"))
    }
}
