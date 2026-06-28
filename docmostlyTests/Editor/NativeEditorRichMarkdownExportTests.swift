import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeEditorRichMarkdownExportTests {
    @Test func documentMarkdownConversionPreservesIframeEmbedMarkdownShape() {
        let source = "https://player.example.com/embed/demo"
        let viewModel = configuredViewModel(blocks: [
            NativeEditorBlock(
                kind: .embed(NativeEditorEmbedBlock(
                    source: source,
                    provider: "iframe",
                    alignment: nil,
                    width: nil,
                    height: nil
                )),
                text: AttributedString(source),
                alignment: .left
            )
        ])

        #expect(viewModel.markdownForDocument() == "[\(source)](\(source))")
    }

    @Test func documentMarkdownConversionPreservesImageTitle() {
        let viewModel = configuredViewModel(blocks: [
            NativeEditorBlock(
                kind: .image(NativeEditorMediaBlock(
                    source: "/files/image.png",
                    alternativeText: "Architecture",
                    title: "System diagram",
                    attachmentID: nil,
                    sizeInBytes: nil,
                    width: nil,
                    height: nil,
                    aspectRatio: nil,
                    alignment: nil
                )),
                text: AttributedString("Architecture"),
                alignment: .left
            )
        ])

        #expect(viewModel.markdownForDocument() == #"![Architecture](/files/image.png "System diagram")"#)
    }

    @Test func documentMarkdownConversionPreservesDocmostPageBreakHTMLShape() {
        let viewModel = configuredViewModel(blocks: [
            NativeEditorBlock(
                kind: .pageBreak,
                text: AttributedString("Page break"),
                alignment: .left
            )
        ])

        #expect(viewModel.markdownForDocument() == #"<div data-type="pageBreak" class="page-break"></div>"#)
    }

    @Test func documentMarkdownConversionPreservesRichBlockMeaning() {
        let viewModel = configuredViewModel(blocks: richMarkdownFixtureBlocks())

        #expect(viewModel.markdownForDocument() == """
        ![Architecture](/files/image.png)
        [Launch demo.mp4](/files/demo.mp4)
        [Release audio.m4a](/files/audio.m4a)
        [Spec.pdf](/files/spec.pdf)
        [Archive.zip](/files/archive.zip)
        :::warning
        Check migration plan
        :::
        <details>
        <summary>Release checklist</summary>

        Ship native editor

        </details>
        <div style="page-break-after: always;"></div>
        [Example](https://example.com)
        $$
        E = mc^2
        $$
        """)
    }

    private func configuredViewModel(blocks: [NativeEditorBlock]) -> NativeRichEditorViewModel {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: blocks)
        viewModel.resetEditingHistory()
        return viewModel
    }

    private func richMarkdownFixtureBlocks() -> [NativeEditorBlock] {
        [
            imageMarkdownFixtureBlock(),
            videoMarkdownFixtureBlock(),
            audioMarkdownFixtureBlock(),
            pdfMarkdownFixtureBlock(),
            attachmentMarkdownFixtureBlock(),
            calloutMarkdownFixtureBlock(),
            detailsMarkdownFixtureBlock(),
            pageBreakMarkdownFixtureBlock(),
            embedMarkdownFixtureBlock(),
            mathMarkdownFixtureBlock()
        ]
    }

    private func imageMarkdownFixtureBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .image(NativeEditorMediaBlock(
                source: "/files/image.png",
                alternativeText: "Architecture",
                title: nil,
                attachmentID: nil,
                sizeInBytes: nil,
                width: nil,
                height: nil,
                aspectRatio: nil,
                alignment: nil
            )),
            text: AttributedString("Architecture"),
            alignment: .left
        )
    }

    private func videoMarkdownFixtureBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .video(NativeEditorMediaBlock(
                source: "/files/demo.mp4",
                alternativeText: nil,
                title: "Launch demo.mp4",
                attachmentID: nil,
                sizeInBytes: nil,
                width: nil,
                height: nil,
                aspectRatio: nil,
                alignment: nil
            )),
            text: AttributedString("Launch demo.mp4"),
            alignment: .left
        )
    }

    private func audioMarkdownFixtureBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .audio(NativeEditorMediaBlock(
                source: "/files/audio.m4a",
                alternativeText: nil,
                title: "Release audio.m4a",
                attachmentID: nil,
                sizeInBytes: nil,
                width: nil,
                height: nil,
                aspectRatio: nil,
                alignment: nil
            )),
            text: AttributedString("Release audio.m4a"),
            alignment: .left
        )
    }

    private func pdfMarkdownFixtureBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .pdf(NativeEditorPDFBlock(
                source: "/files/spec.pdf",
                name: "Spec.pdf",
                attachmentID: nil,
                sizeInBytes: nil,
                width: nil,
                height: nil
            )),
            text: AttributedString("Spec.pdf"),
            alignment: .left
        )
    }

    private func attachmentMarkdownFixtureBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .attachment(NativeEditorAttachmentBlock(
                url: "/files/archive.zip",
                name: "Archive.zip",
                mimeType: "application/zip",
                sizeInBytes: nil,
                attachmentID: nil
            )),
            text: AttributedString("Archive.zip"),
            alignment: .left
        )
    }

    private func calloutMarkdownFixtureBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .callout(NativeEditorCalloutBlock(
                style: "warning",
                icon: nil,
                previewText: "Check migration plan"
            )),
            text: AttributedString("Check migration plan"),
            alignment: .left
        )
    }

    private func detailsMarkdownFixtureBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .details(NativeEditorDetailsBlock(
                summary: "Release checklist",
                previewText: "Ship native editor",
                isOpen: true
            )),
            text: AttributedString("Release checklist"),
            alignment: .left
        )
    }

    private func pageBreakMarkdownFixtureBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .pageBreak,
            text: AttributedString("Page break"),
            alignment: .left
        )
    }

    private func embedMarkdownFixtureBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .embed(NativeEditorEmbedBlock(
                source: "https://example.com",
                provider: "Example",
                alignment: nil,
                width: nil,
                height: nil
            )),
            text: AttributedString("Example"),
            alignment: .left
        )
    }

    private func mathMarkdownFixtureBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .mathBlock(NativeEditorMathBlock(text: "E = mc^2")),
            text: AttributedString("E = mc^2"),
            alignment: .left
        )
    }
}
