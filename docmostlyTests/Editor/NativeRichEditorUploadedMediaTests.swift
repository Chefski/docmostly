import Foundation
import Testing
@testable import docmostly

@MainActor
struct NativeRichEditorUploadedMediaTests {
    @Test func insertingUploadedImageUsesDocmostDefaultCenterAlignment() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("/image"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.insertUploadedAttachment(
            uploadedAttachment(fileName: "Diagram.png", mimeType: "image/png", fileExt: "png"),
            as: .image
        )

        guard case .image(let image) = viewModel.document.blocks[0].kind else {
            Issue.record("Expected uploaded image to become an image block.")
            return
        }

        let node = viewModel.document.proseMirrorDocument.content.first
        #expect(image.alignment == "center")
        #expect(node?.attrs?["align"] == .string("center"))
    }

    @Test func insertingUploadedVideoUsesDocmostDefaultCenterAlignment() {
        let block = NativeEditorBlock(kind: .paragraph, text: AttributedString("/video"), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [block])
        viewModel.focus(blockID: block.id)

        viewModel.insertUploadedAttachment(
            uploadedAttachment(fileName: "Demo.mp4", mimeType: "video/mp4", fileExt: "mp4"),
            as: .video
        )

        guard case .video(let video) = viewModel.document.blocks[0].kind else {
            Issue.record("Expected uploaded video to become a video block.")
            return
        }

        let node = viewModel.document.proseMirrorDocument.content.first
        #expect(video.alignment == "center")
        #expect(node?.attrs?["align"] == .string("center"))
    }

    private func uploadedAttachment(
        fileName: String,
        mimeType: String,
        fileExt: String
    ) -> DocmostAttachment {
        DocmostAttachment(
            id: "attachment-1",
            fileName: fileName,
            filePath: nil,
            fileSize: 4096,
            fileExt: fileExt,
            mimeType: mimeType,
            type: "file",
            creatorId: "user-1",
            pageId: "page-1",
            spaceId: "space-1",
            workspaceId: "workspace-1",
            createdAt: nil,
            updatedAt: nil,
            deletedAt: nil
        )
    }
}
