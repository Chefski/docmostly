import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorMediaHTMLFidelityTests {
    @Test func exportsDocmostMediaAndEmbedHTMLShapes() {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: nativeBlocks())
        viewModel.resetEditingHistory()

        #expect(viewModel.markdownForDocument() == docmostHTMLMarkdown())
    }

    @Test func importsDocmostMediaAndEmbedHTMLAsTypedNativeBlocks() throws {
        let markdown = docmostHTMLMarkdown()
        let blocks = NativeEditorMarkdownParser.blocks(from: markdown)

        try #require(blocks.count == 6)
        verifyImage(blocks[0])
        verifyVideo(blocks[1])
        verifyAudio(blocks[2])
        verifyPDF(blocks[3])
        verifyAttachment(blocks[4])
        verifyEmbed(blocks[5])
        #expect(NativeEditorMarkdownParser.markdown(from: blocks) == markdown)
    }

    @Test func importsCompactDocmostMediaAndEmbedHTMLAsTypedNativeBlocks() throws {
        let blocks = NativeEditorMarkdownParser.blocks(from: compactDocmostHTMLMarkdown())

        try #require(blocks.count == 5)
        verifyVideo(blocks[0])
        verifyAudio(blocks[1])
        verifyPDF(blocks[2])
        verifyAttachment(blocks[3])
        verifyEmbed(blocks[4])
    }

    private func nativeBlocks() -> [NativeEditorBlock] {
        [
            NativeEditorBlock(kind: .image(imageBlock()), text: AttributedString("Hero"), alignment: .left),
            NativeEditorBlock(kind: .video(videoBlock()), text: AttributedString("Launch demo"), alignment: .left),
            NativeEditorBlock(kind: .audio(audioBlock()), text: AttributedString("Audio"), alignment: .left),
            NativeEditorBlock(kind: .pdf(pdfBlock()), text: AttributedString("Spec.pdf"), alignment: .left),
            NativeEditorBlock(
                kind: .attachment(attachmentBlock()),
                text: AttributedString("Archive.zip"),
                alignment: .left
            ),
            NativeEditorBlock(kind: .embed(embedBlock()), text: AttributedString("Figma"), alignment: .left)
        ]
    }

    private func imageBlock() -> NativeEditorMediaBlock {
        NativeEditorMediaBlock(
            source: "/api/files/image-1/Hero.png",
            alternativeText: "Hero",
            title: "Launch hero",
            attachmentID: "image-1",
            sizeInBytes: 2_048,
            width: "640",
            height: "360",
            aspectRatio: "1.7777778",
            alignment: "center"
        )
    }

    private func videoBlock() -> NativeEditorMediaBlock {
        NativeEditorMediaBlock(
            source: "/api/files/video-1/Demo.mp4",
            alternativeText: "Launch demo",
            title: nil,
            attachmentID: "video-1",
            sizeInBytes: 8_192,
            width: "75%",
            height: "360",
            aspectRatio: "1.7777778",
            alignment: "right"
        )
    }

    private func audioBlock() -> NativeEditorMediaBlock {
        NativeEditorMediaBlock(
            source: "/api/files/audio-1/Briefing.m4a",
            alternativeText: nil,
            title: nil,
            attachmentID: "audio-1",
            sizeInBytes: 4_096,
            width: nil,
            height: nil,
            aspectRatio: nil,
            alignment: nil
        )
    }

    private func pdfBlock() -> NativeEditorPDFBlock {
        NativeEditorPDFBlock(
            source: "/api/files/pdf-1/Spec.pdf",
            name: "Spec.pdf",
            attachmentID: "pdf-1",
            sizeInBytes: 16_384,
            width: "800",
            height: "600"
        )
    }

    private func attachmentBlock() -> NativeEditorAttachmentBlock {
        NativeEditorAttachmentBlock(
            url: "/api/files/file-1/Archive.zip",
            name: "Archive.zip",
            mimeType: "application/zip",
            sizeInBytes: 1_024,
            attachmentID: "file-1"
        )
    }

    private func embedBlock() -> NativeEditorEmbedBlock {
        NativeEditorEmbedBlock(
            source: "https://www.figma.com/file/demo",
            provider: "Figma",
            alignment: "center",
            width: "800",
            height: "600"
        )
    }

    private func docmostHTMLMarkdown() -> String {
        [
            imageHTML(),
            videoHTML(),
            audioHTML(),
            pdfHTML(),
            attachmentHTML(),
            embedHTML()
        ].joined(separator: "\n")
    }

    private func compactDocmostHTMLMarkdown() -> String {
        [
            compactVideoHTML(),
            compactAudioHTML(),
            compactPDFHTML(),
            compactAttachmentHTML(),
            compactEmbedHTML()
        ].joined(separator: "\n")
    }

    private func imageHTML() -> String {
        htmlTag("img", attributes: [
            ("src", "/api/files/image-1/Hero.png"),
            ("alt", "Hero"),
            ("title", "Launch hero"),
            ("width", "640"),
            ("height", "360"),
            ("data-align", "center"),
            ("data-attachment-id", "image-1"),
            ("data-size", "2048"),
            ("data-aspect-ratio", "1.7777778")
        ])
    }

    private func videoHTML() -> String {
        """
        \(htmlTag("video", attributes: videoAttributes()))
        <source src="/api/files/video-1/Demo.mp4">
        </video>
        """
    }

    private func compactVideoHTML() -> String {
        [
            htmlTag("video", attributes: compactVideoAttributes()),
            #"<source src="/api/files/video-1/Demo.mp4"></video>"#
        ].joined()
    }

    private func videoAttributes() -> [(String, String?)] {
        [
            ("controls", "true"),
            ("src", "/api/files/video-1/Demo.mp4"),
            ("aria-label", "Launch demo"),
            ("data-attachment-id", "video-1"),
            ("width", "75%"),
            ("height", "360"),
            ("data-size", "8192"),
            ("data-align", "right"),
            ("data-aspect-ratio", "1.7777778")
        ]
    }

    private func compactVideoAttributes() -> [(String, String?)] {
        videoAttributes().filter { key, _ in key != "src" }
    }

    private func audioHTML() -> String {
        """
        \(htmlTag("audio", attributes: audioAttributes()))
        <source src="/api/files/audio-1/Briefing.m4a">
        </audio>
        """
    }

    private func compactAudioHTML() -> String {
        [
            htmlTag("audio", attributes: compactAudioAttributes()),
            #"<source src="/api/files/audio-1/Briefing.m4a"></audio>"#
        ].joined()
    }

    private func audioAttributes() -> [(String, String?)] {
        [
            ("controls", "true"),
            ("preload", "metadata"),
            ("src", "/api/files/audio-1/Briefing.m4a"),
            ("data-attachment-id", "audio-1"),
            ("data-size", "4096")
        ]
    }

    private func compactAudioAttributes() -> [(String, String?)] {
        audioAttributes().filter { key, _ in key != "src" }
    }

    private func pdfHTML() -> String {
        """
        \(htmlTag("div", attributes: pdfContainerAttributes()))
        <iframe src="/api/files/pdf-1/Spec.pdf" width="800" height="600"></iframe>
        </div>
        """
    }

    private func compactPDFHTML() -> String {
        [
            htmlTag("div", attributes: compactPDFContainerAttributes()),
            #"<iframe src="/api/files/pdf-1/Spec.pdf" width="800" height="600"></iframe></div>"#
        ].joined()
    }

    private func pdfContainerAttributes() -> [(String, String?)] {
        [
            ("data-type", "pdf"),
            ("src", "/api/files/pdf-1/Spec.pdf"),
            ("data-name", "Spec.pdf"),
            ("data-attachment-id", "pdf-1"),
            ("data-size", "16384"),
            ("width", "800"),
            ("height", "600")
        ]
    }

    private func compactPDFContainerAttributes() -> [(String, String?)] {
        pdfContainerAttributes().filter { key, _ in key != "src" }
    }

    private func attachmentHTML() -> String {
        """
        \(htmlTag("div", attributes: attachmentContainerAttributes()))
        <a href="/api/files/file-1/Archive.zip" class="attachment" target="blank">Archive.zip</a>
        </div>
        """
    }

    private func compactAttachmentHTML() -> String {
        [
            htmlTag("div", attributes: compactAttachmentContainerAttributes()),
            #"<a href="/api/files/file-1/Archive.zip" class="attachment" target="blank">"#,
            "Archive.zip</a></div>"
        ].joined()
    }

    private func attachmentContainerAttributes() -> [(String, String?)] {
        [
            ("data-type", "attachment"),
            ("data-attachment-url", "/api/files/file-1/Archive.zip"),
            ("data-attachment-name", "Archive.zip"),
            ("data-attachment-mime", "application/zip"),
            ("data-attachment-size", "1024"),
            ("data-attachment-id", "file-1")
        ]
    }

    private func compactAttachmentContainerAttributes() -> [(String, String?)] {
        attachmentContainerAttributes().filter { key, _ in key != "data-attachment-url" }
    }

    private func embedHTML() -> String {
        """
        \(htmlTag("div", attributes: embedContainerAttributes()))
        <a href="https://www.figma.com/file/demo" target="blank">https://www.figma.com/file/demo</a>
        </div>
        """
    }

    private func compactEmbedHTML() -> String {
        [
            htmlTag("div", attributes: compactEmbedContainerAttributes()),
            #"<a href="https://www.figma.com/file/demo" target="blank">"#,
            "https://www.figma.com/file/demo</a></div>"
        ].joined()
    }

    private func embedContainerAttributes() -> [(String, String?)] {
        [
            ("data-type", "embed"),
            ("data-src", "https://www.figma.com/file/demo"),
            ("data-provider", "Figma"),
            ("data-align", "center"),
            ("data-width", "800"),
            ("data-height", "600")
        ]
    }

    private func compactEmbedContainerAttributes() -> [(String, String?)] {
        embedContainerAttributes().filter { key, _ in key != "data-src" }
    }

    private func verifyImage(_ block: NativeEditorBlock) {
        guard case .image(let image) = block.kind else {
            Issue.record("Expected Docmost image HTML to import as a native image block.")
            return
        }

        #expect(image.source == "/api/files/image-1/Hero.png")
        #expect(image.alternativeText == "Hero")
        #expect(image.title == "Launch hero")
        #expect(image.attachmentID == "image-1")
        #expect(image.sizeInBytes == 2_048)
        #expect(image.width == "640")
        #expect(image.height == "360")
        #expect(image.aspectRatio == "1.7777778")
        #expect(image.alignment == "center")
        #expect(block.rawNode?.type == "image")
        #expect(block.rawNode?.attrs?["title"] == .string("Launch hero"))
        #expect(block.rawNode?.attrs?["width"] == .int(640))
    }

    private func verifyVideo(_ block: NativeEditorBlock) {
        guard case .video(let video) = block.kind else {
            Issue.record("Expected Docmost video HTML to import as a native video block.")
            return
        }

        #expect(video.source == "/api/files/video-1/Demo.mp4")
        #expect(video.alternativeText == "Launch demo")
        #expect(video.attachmentID == "video-1")
        #expect(video.sizeInBytes == 8_192)
        #expect(video.width == "75%")
        #expect(video.height == "360")
        #expect(video.aspectRatio == "1.7777778")
        #expect(video.alignment == "right")
        #expect(block.rawNode?.type == "video")
        #expect(block.rawNode?.attrs?["width"] == .string("75%"))
    }

    private func verifyAudio(_ block: NativeEditorBlock) {
        guard case .audio(let audio) = block.kind else {
            Issue.record("Expected Docmost audio HTML to import as a native audio block.")
            return
        }

        #expect(audio.source == "/api/files/audio-1/Briefing.m4a")
        #expect(audio.attachmentID == "audio-1")
        #expect(audio.sizeInBytes == 4_096)
        #expect(block.rawNode?.type == "audio")
    }

    private func verifyPDF(_ block: NativeEditorBlock) {
        guard case .pdf(let pdf) = block.kind else {
            Issue.record("Expected Docmost PDF HTML to import as a native PDF block.")
            return
        }

        #expect(pdf.source == "/api/files/pdf-1/Spec.pdf")
        #expect(pdf.name == "Spec.pdf")
        #expect(pdf.attachmentID == "pdf-1")
        #expect(pdf.sizeInBytes == 16_384)
        #expect(pdf.width == "800")
        #expect(pdf.height == "600")
        #expect(block.rawNode?.type == "pdf")
    }

    private func verifyAttachment(_ block: NativeEditorBlock) {
        guard case .attachment(let attachment) = block.kind else {
            Issue.record("Expected Docmost attachment HTML to import as a native attachment block.")
            return
        }

        #expect(attachment.url == "/api/files/file-1/Archive.zip")
        #expect(attachment.name == "Archive.zip")
        #expect(attachment.mimeType == "application/zip")
        #expect(attachment.sizeInBytes == 1_024)
        #expect(attachment.attachmentID == "file-1")
        #expect(block.rawNode?.type == "attachment")
    }

    private func verifyEmbed(_ block: NativeEditorBlock) {
        guard case .embed(let embed) = block.kind else {
            Issue.record("Expected Docmost embed HTML to import as a native embed block.")
            return
        }

        #expect(embed.source == "https://www.figma.com/file/demo")
        #expect(embed.provider == "Figma")
        #expect(embed.alignment == "center")
        #expect(embed.width == "800")
        #expect(embed.height == "600")
        #expect(block.rawNode?.type == "embed")
    }

    private func htmlTag(_ name: String, attributes: [(String, String?)]) -> String {
        let attributeText = attributes.compactMap { key, value -> String? in
            value.map { #"\#(key)="\#($0)""# }
        }.joined(separator: " ")
        return "<\(name) \(attributeText)>"
    }
}
