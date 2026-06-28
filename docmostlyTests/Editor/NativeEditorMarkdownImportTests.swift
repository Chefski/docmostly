import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorMarkdownImportTests {
    @Test func markdownSingleNewlinesImportAsHardBreaksInsideParagraph() throws {
        let blocks = NativeEditorMarkdownParser.blocks(from: """
        Line one
        Line two
        """)

        #expect(blocks.count == 1)
        let block = try #require(blocks.first)
        #expect(block.kind == .paragraph)
        #expect(String(block.text.characters) == "Line one\nLine two")

        let node = NativeEditorDocument.node(from: block)
        #expect(node.content?.map(\.type) == ["text", "hardBreak", "text"])
        #expect(node.content?.first?.text == "Line one")
        #expect(node.content?.last?.text == "Line two")
    }

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

    @Test func docmostAttachmentLinksImportWithAttachmentIDs() throws {
        let blocks = NativeEditorMarkdownParser.blocks(from: """
        ![Hero](/api/files/image-1/Hero.png)
        [Launch demo.mp4](/api/files/video-1/Launch%20demo.mp4)
        [Spec.pdf](/api/files/pdf-1/Spec.pdf)
        [Archive.zip](/api/files/file-1/Archive.zip)
        """)

        #expect(blocks.count == 4)

        guard case .image(let image) = blocks[0].kind else {
            Issue.record("Expected Docmost image link to import as an image block.")
            return
        }
        #expect(image.attachmentID == "image-1")
        #expect(blocks[0].rawNode?.attrs?["attachmentId"] == .string("image-1"))

        guard case .video(let video) = blocks[1].kind else {
            Issue.record("Expected Docmost video link to import as a video block.")
            return
        }
        #expect(video.attachmentID == "video-1")
        #expect(blocks[1].rawNode?.attrs?["attachmentId"] == .string("video-1"))

        guard case .pdf(let pdf) = blocks[2].kind else {
            Issue.record("Expected Docmost PDF link to import as a PDF block.")
            return
        }
        #expect(pdf.attachmentID == "pdf-1")
        #expect(blocks[2].rawNode?.attrs?["attachmentId"] == .string("pdf-1"))

        guard case .attachment(let attachment) = blocks[3].kind else {
            Issue.record("Expected Docmost file link to import as an attachment block.")
            return
        }
        #expect(attachment.attachmentID == "file-1")
        #expect(blocks[3].rawNode?.attrs?["attachmentId"] == .string("file-1"))
    }

    @Test func markdownImageTitleImportsAsNativeMediaTitle() throws {
        let block = try #require(NativeEditorMarkdownParser.blocks(
            from: #"![Architecture](/files/image.png "System diagram")"#
        ).first)

        guard case .image(let image) = block.kind else {
            Issue.record("Expected Markdown image to import as a native image block.")
            return
        }

        #expect(image.source == "/files/image.png")
        #expect(image.alternativeText == "Architecture")
        #expect(image.title == "System diagram")
        #expect(block.rawNode?.attrs?["title"] == .string("System diagram"))
    }

    @Test func docmostIframeMarkdownLinksImportAsEmbedBlocks() throws {
        let source = "https://player.example.com/embed/demo"
        let block = try #require(NativeEditorMarkdownParser.blocks(from: "[\(source)](\(source))").first)

        guard case .embed(let embed) = block.kind else {
            Issue.record("Expected Docmost iframe Markdown link to import as a native embed block.")
            return
        }

        #expect(embed.source == source)
        #expect(embed.provider == "iframe")
        #expect(block.rawNode?.type == "embed")
        #expect(block.rawNode?.attrs?["src"] == .string(source))
        #expect(block.rawNode?.attrs?["provider"] == .string("iframe"))
    }

    @Test func genericMarkdownLinksRemainEditableParagraphText() throws {
        let block = try #require(NativeEditorMarkdownParser.blocks(from: "[Example](https://example.com)").first)

        #expect(block.kind == .paragraph)
        #expect(String(block.text.characters) == "Example")
    }
}
