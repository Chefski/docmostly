import Foundation
import SwiftUI
import Testing
@testable import docmostly

@MainActor
struct NativeRichEditorAttachmentTests {
    @Test func insertingMultipleUploadedFilesPreservesEverySelectedAttachment() {
        let placeholder = NativeEditorBlock(kind: .paragraph, text: AttributedString(), alignment: .left)
        let viewModel = NativeRichEditorViewModel(pageID: "page-1", initialTitle: "Page")
        viewModel.document = NativeEditorDocument(blocks: [placeholder])

        viewModel.insertUploadedAttachments(
            [
                (
                    attachment: uploadedAttachment(id: "attachment-1", fileName: "Report.pdf"),
                    sourceFileURL: nil
                ),
                (
                    attachment: uploadedAttachment(id: "attachment-2", fileName: "Spec.pdf"),
                    sourceFileURL: nil
                )
            ],
            as: .file
        )

        #expect(viewModel.document.blocks.count == 2)

        let firstBlock = viewModel.document.blocks[0]
        let secondBlock = viewModel.document.blocks[1]
        guard case .attachment(let firstAttachment) = firstBlock.kind else {
            Issue.record("Expected first uploaded file to become an attachment block")
            return
        }
        guard case .attachment(let secondAttachment) = secondBlock.kind else {
            Issue.record("Expected second uploaded file to become an attachment block")
            return
        }

        #expect(firstBlock.id == placeholder.id)
        #expect(firstAttachment.attachmentID == "attachment-1")
        #expect(firstAttachment.name == "Report.pdf")
        #expect(secondAttachment.attachmentID == "attachment-2")
        #expect(secondAttachment.name == "Spec.pdf")
        #expect(viewModel.selectedBlockID == secondBlock.id)
        #expect(viewModel.visibleBlockControlsID == secondBlock.id)
        #expect(viewModel.isDirty == true)
    }

    private func uploadedAttachment(id: String, fileName: String) -> DocmostAttachment {
        DocmostAttachment(
            id: id,
            fileName: fileName,
            filePath: nil,
            fileSize: 4096,
            fileExt: "pdf",
            mimeType: "application/pdf",
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
