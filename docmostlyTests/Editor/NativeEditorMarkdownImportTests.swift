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

    @Test func docmostPageBreakHTMLImportsAsNativePageBreakBlock() throws {
        let block = try #require(NativeEditorMarkdownParser.blocks(
            from: #"<div data-type="pageBreak" class="page-break"></div>"#
        ).first)

        #expect(block.kind == .pageBreak)
        #expect(block.rawNode?.type == "pageBreak")
    }

    @Test func legacyPageBreakHTMLImportsAsNativePageBreakBlock() throws {
        let block = try #require(NativeEditorMarkdownParser.blocks(
            from: #"<div style="page-break-after: always;"></div>"#
        ).first)

        #expect(block.kind == .pageBreak)
        #expect(block.rawNode?.type == "pageBreak")
    }

    @Test func docmostColumnsHTMLImportsAsNativeColumnsBlock() throws {
        let markdown = """
        <div data-type="columns" data-layout="two_left_sidebar" data-width-mode="wide">
        <div data-type="column" data-width="0.6" style="flex: 0.6">
        Navigation
        </div>
        <div data-type="column" data-width="1.4" style="flex: 1.4">
        Main content
        </div>
        </div>
        """
        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)

        guard case .columns(let columns) = block.kind else {
            Issue.record("Expected Docmost columns HTML to import as a native columns block.")
            return
        }

        #expect(columns.layout == "two_left_sidebar")
        #expect(columns.widthMode == "wide")
        #expect(columns.columnCount == 2)
        #expect(columns.columnTexts == ["Navigation", "Main content"])
        #expect(block.rawNode?.type == "columns")
        #expect(block.rawNode?.attrs?["layout"] == .string("two_left_sidebar"))
        #expect(block.rawNode?.attrs?["widthMode"] == .string("wide"))
        #expect(block.rawNode?.content?.map(\.type) == ["column", "column"])
        #expect(block.rawNode?.content?[0].attrs?["width"] == .double(0.6))
        #expect(block.rawNode?.content?[1].attrs?["width"] == .double(1.4))
        #expect(NativeEditorMarkdownParser.markdown(from: [block]) == markdown)
    }

    @Test func docmostDiagramHTMLImportsAsNativeDiagramBlocks() throws {
        let drawioSource = "/api/files/drawio-1/diagram.drawio.svg"
        let excalidrawSource = "/api/files/excalidraw-1/sketch.png"
        let markdown = [
            docmostDiagramHTML(
                type: "drawio",
                source: drawioSource,
                title: "System map",
                alternativeText: "System diagram",
                attachmentID: "drawio-1",
                size: "2048",
                width: "640",
                height: "360",
                aspectRatio: "1.7777778",
                alignment: "center"
            ),
            docmostDiagramHTML(
                type: "excalidraw",
                source: excalidrawSource,
                title: "Sketch",
                alternativeText: "Whiteboard sketch",
                attachmentID: "excalidraw-1",
                width: "75%",
                alignment: "right"
            )
        ].joined(separator: "\n")
        let blocks = NativeEditorMarkdownParser.blocks(from: markdown)

        try #require(blocks.count == 2)
        guard case .drawio(let drawio) = blocks[0].kind else {
            Issue.record("Expected Docmost draw.io HTML to import as a native draw.io block.")
            return
        }
        guard case .excalidraw(let excalidraw) = blocks[1].kind else {
            Issue.record("Expected Docmost Excalidraw HTML to import as a native Excalidraw block.")
            return
        }

        #expect(drawio.source == drawioSource)
        #expect(drawio.title == "System map")
        #expect(drawio.alternativeText == "System diagram")
        #expect(drawio.attachmentID == "drawio-1")
        #expect(drawio.sizeInBytes == 2_048)
        #expect(drawio.width == "640")
        #expect(drawio.height == "360")
        #expect(drawio.aspectRatio == "1.7777778")
        #expect(drawio.alignment == "center")
        #expect(blocks[0].rawNode?.type == "drawio")
        #expect(blocks[0].rawNode?.attrs?["src"] == .string(drawioSource))
        #expect(blocks[0].rawNode?.attrs?["width"] == .int(640))
        #expect(blocks[0].rawNode?.attrs?["attachmentId"] == .string("drawio-1"))
        #expect(excalidraw.source == excalidrawSource)
        #expect(excalidraw.width == "75%")
        #expect(blocks[1].rawNode?.type == "excalidraw")
        #expect(blocks[1].rawNode?.attrs?["width"] == .string("75%"))
        #expect(NativeEditorMarkdownParser.markdown(from: blocks) == markdown)
    }

    @Test func docmostStructuralHTMLImportsAsNativeStructuralBlocks() throws {
        let markdown = """
        <div data-type="subpages"></div>
        <div data-type="transclusionSource" data-id="sync-1">
        Reusable launch checklist
        </div>
        <div data-type="transclusionReference" data-source-page-id="page-1" data-transclusion-id="sync-1"></div>
        <div data-type="base-embed" data-page-id="base-page-1"></div>
        """
        let blocks = NativeEditorMarkdownParser.blocks(from: markdown)

        try #require(blocks.count == 4)
        #expect(blocks[0].kind == .subpages)
        #expect(blocks[0].rawNode?.type == "subpages")

        guard case .transclusionSource(let source) = blocks[1].kind else {
            Issue.record("Expected Docmost transclusion source HTML to import as a native synced block.")
            return
        }
        #expect(source.identifier == "sync-1")
        #expect(source.previewText == "Reusable launch checklist")
        #expect(blocks[1].rawNode?.type == "transclusionSource")
        #expect(blocks[1].rawNode?.attrs?["id"] == .string("sync-1"))

        guard case .transclusionReference(let reference) = blocks[2].kind else {
            Issue.record("Expected Docmost transclusion reference HTML to import as a native synced block reference.")
            return
        }
        #expect(reference.sourcePageID == "page-1")
        #expect(reference.transclusionID == "sync-1")
        #expect(blocks[2].rawNode?.type == "transclusionReference")
        #expect(blocks[2].rawNode?.attrs?["sourcePageId"] == .string("page-1"))
        #expect(blocks[2].rawNode?.attrs?["transclusionId"] == .string("sync-1"))

        guard case .base(let base) = blocks[3].kind else {
            Issue.record("Expected Docmost base embed HTML to import as a native base block.")
            return
        }
        #expect(base.pageID == "base-page-1")
        #expect(base.pendingKey == nil)
        #expect(blocks[3].rawNode?.type == "base")
        #expect(blocks[3].rawNode?.attrs?["pageId"] == .string("base-page-1"))
        #expect(NativeEditorMarkdownParser.markdown(from: blocks) == markdown)
    }

    @Test func singleLineDocmostDiagramHTMLImportsAsNativeDiagramBlock() throws {
        let source = "/api/files/drawio-1/diagram.drawio.svg"
        let markdown = singleLineDocmostDiagramHTML(
            type: "drawio",
            source: source,
            title: "System map",
            alternativeText: "System diagram",
            attachmentID: "drawio-1",
            width: "640"
        )
        let block = try #require(NativeEditorMarkdownParser.blocks(from: markdown).first)

        guard case .drawio(let drawio) = block.kind else {
            Issue.record("Expected compact Docmost draw.io HTML to import as a native draw.io block.")
            return
        }

        #expect(drawio.source == source)
        #expect(drawio.title == "System map")
        #expect(drawio.alternativeText == "System diagram")
        #expect(drawio.attachmentID == "drawio-1")
        #expect(drawio.width == "640")
        #expect(block.rawNode?.type == "drawio")
        #expect(block.rawNode?.attrs?["src"] == .string(source))
    }

    @Test func longerHTMLTagNamesDoNotImportAsDocmostMediaBlocks() throws {
        let imageLikeBlock = try #require(
            NativeEditorMarkdownParser.blocks(from: #"<imgproxy src="/files/hero.png">"#).first
        )
        let diagramLikeBlock = try #require(
            NativeEditorMarkdownParser.blocks(
                from: #"<divergent data-type="drawio" data-src="/files/map.svg"><img src="/files/map.svg"></divergent>"#
            ).first
        )

        #expect(imageLikeBlock.kind == .paragraph)
        #expect(String(imageLikeBlock.text.characters) == #"<imgproxy src="/files/hero.png">"#)
        #expect(diagramLikeBlock.kind == .paragraph)
        #expect(String(diagramLikeBlock.text.characters).contains("<divergent"))
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

    private func docmostDiagramHTML(
        type: String,
        source: String,
        title: String,
        alternativeText: String,
        attachmentID: String,
        size: String? = nil,
        width: String? = nil,
        height: String? = nil,
        aspectRatio: String? = nil,
        alignment: String? = nil
    ) -> String {
        let openingTag = htmlTag("div", attributes: [
            ("data-type", type),
            ("data-src", source),
            ("data-title", title),
            ("data-alt", alternativeText),
            ("data-width", width),
            ("data-height", height),
            ("data-size", size),
            ("data-aspect-ratio", aspectRatio),
            ("data-align", alignment),
            ("data-attachment-id", attachmentID)
        ])
        let imageTag = htmlTag("img", attributes: [
            ("src", source),
            ("alt", alternativeText),
            ("width", width)
        ])

        return """
        \(openingTag)
        \(imageTag)
        </div>
        """
    }

    private func singleLineDocmostDiagramHTML(
        type: String,
        source: String,
        title: String,
        alternativeText: String,
        attachmentID: String,
        width: String? = nil
    ) -> String {
        let openingTag = htmlTag("div", attributes: [
            ("data-type", type),
            ("data-src", source),
            ("data-title", title),
            ("data-alt", alternativeText),
            ("data-width", width),
            ("data-attachment-id", attachmentID)
        ])
        let imageTag = htmlTag("img", attributes: [
            ("src", source),
            ("alt", alternativeText),
            ("width", width)
        ])

        return "\(openingTag)\(imageTag)</div>"
    }

    private func htmlTag(_ name: String, attributes: [(String, String?)]) -> String {
        let attributeText = attributes.compactMap { key, value -> String? in
            value.map { #"\#(key)="\#($0)""# }
        }.joined(separator: " ")
        return "<\(name) \(attributeText)>"
    }
}
