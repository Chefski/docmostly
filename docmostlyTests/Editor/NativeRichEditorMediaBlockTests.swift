import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeRichEditorMediaBlockTests {
    @Test func updatesImagePDFAndAttachmentMetadata() {
        let viewModel = mediaBlockViewModel()
        let imageID = viewModel.document.blocks[0].id
        let pdfID = viewModel.document.blocks[1].id
        let attachmentID = viewModel.document.blocks[2].id

        viewModel.updateMediaBlock(
            blockID: imageID,
            update: NativeEditorMediaBlockUpdate(
                source: "/files/hero.png",
                alternativeText: "Hero image",
                width: "1024",
                height: "768",
                alignment: "center"
            )
        )
        viewModel.updatePDFBlock(
            blockID: pdfID,
            source: "/files/spec-v2.pdf",
            name: "Spec v2.pdf",
            width: "840",
            height: "1188"
        )
        viewModel.updateAttachmentBlock(
            blockID: attachmentID,
            url: "/files/archive-v2.zip",
            name: "Archive v2.zip",
            mimeType: "application/zip"
        )

        let nodes = viewModel.document.proseMirrorDocument.content
        #expect(nodes[0].type == "image")
        #expect(nodes[0].attrs?["src"] == .string("/files/hero.png"))
        #expect(nodes[0].attrs?["alt"] == .string("Hero image"))
        #expect(nodes[0].attrs?["width"] == .int(1024))
        #expect(nodes[0].attrs?["height"] == .int(768))
        #expect(nodes[0].attrs?["align"] == .string("center"))

        #expect(nodes[1].type == "pdf")
        #expect(nodes[1].attrs?["src"] == .string("/files/spec-v2.pdf"))
        #expect(nodes[1].attrs?["name"] == .string("Spec v2.pdf"))
        #expect(nodes[1].attrs?["width"] == .int(840))
        #expect(nodes[1].attrs?["height"] == .int(1188))

        #expect(nodes[2].type == "attachment")
        #expect(nodes[2].attrs?["url"] == .string("/files/archive-v2.zip"))
        #expect(nodes[2].attrs?["name"] == .string("Archive v2.zip"))
        #expect(nodes[2].attrs?["mime"] == .string("application/zip"))
    }

    private func mediaBlockViewModel() -> NativeRichEditorViewModel {
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [
            imageBlock(),
            pdfBlock(),
            attachmentBlock()
        ])
        return viewModel
    }

    private func imageBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .image(NativeEditorMediaBlock(
                source: "/files/hero-old.png",
                alternativeText: nil,
                attachmentID: "image-1",
                sizeInBytes: 2048,
                width: nil,
                height: nil,
                aspectRatio: nil,
                alignment: nil
            )),
            text: AttributedString("Image"),
            alignment: .left
        )
    }

    private func pdfBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .pdf(NativeEditorPDFBlock(
                source: "/files/spec.pdf",
                name: "Spec.pdf",
                attachmentID: "pdf-1",
                sizeInBytes: 4096,
                width: nil,
                height: nil
            )),
            text: AttributedString("Spec.pdf"),
            alignment: .left
        )
    }

    private func attachmentBlock() -> NativeEditorBlock {
        NativeEditorBlock(
            kind: .attachment(NativeEditorAttachmentBlock(
                url: "/files/archive.zip",
                name: "Archive.zip",
                mimeType: "application/zip",
                sizeInBytes: 1024,
                attachmentID: "file-1"
            )),
            text: AttributedString("Archive.zip"),
            alignment: .left
        )
    }
}
