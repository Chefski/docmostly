import Foundation

extension NativeRichEditorViewModel {
    func insertUploadedAttachment(
        _ attachment: DocmostAttachment,
        as importKind: NativeEditorAttachmentImportKind,
        sourceFileURL: URL? = nil
    ) {
        performUndoableEdit {
            insertUploadedAttachmentInCurrentDocument(
                attachment,
                as: importKind,
                sourceFileURL: sourceFileURL
            )
        }
    }

    func insertUploadedAttachments(
        _ attachments: [(attachment: DocmostAttachment, sourceFileURL: URL?)],
        as importKind: NativeEditorAttachmentImportKind
    ) {
        guard attachments.isEmpty == false else { return }

        performUndoableEdit {
            for uploadedAttachment in attachments {
                insertUploadedAttachmentInCurrentDocument(
                    uploadedAttachment.attachment,
                    as: importKind,
                    sourceFileURL: uploadedAttachment.sourceFileURL
                )
            }
        }
    }

    private var emptyPlaceholderBlockIndex: Array<NativeEditorBlock>.Index? {
        guard document.blocks.count == 1, let block = document.blocks.first else {
            return nil
        }

        guard block.kind == .paragraph, block.inlineContent == nil else {
            return nil
        }

        let text = String(block.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? document.blocks.startIndex : nil
    }

    private func insertUploadedAttachmentInCurrentDocument(
        _ attachment: DocmostAttachment,
        as importKind: NativeEditorAttachmentImportKind,
        sourceFileURL: URL? = nil
    ) {
        if let index = activeBlockIndex {
            let block = NativeEditorAttachmentBlockFactory.block(
                for: attachment,
                importKind: importKind,
                replacing: document.blocks[index].id,
                sourceFileURL: sourceFileURL
            )
            document.blocks[index] = block
            selectedBlockID = block.id
            visibleBlockControlsID = block.id
            activeBlockID = nil
            return
        }

        if let placeholderIndex = emptyPlaceholderBlockIndex {
            let block = NativeEditorAttachmentBlockFactory.block(
                for: attachment,
                importKind: importKind,
                replacing: document.blocks[placeholderIndex].id,
                sourceFileURL: sourceFileURL
            )
            document.blocks[placeholderIndex] = block
            selectedBlockID = block.id
            visibleBlockControlsID = block.id
            activeBlockID = nil
            return
        }

        let block = NativeEditorAttachmentBlockFactory.block(
            for: attachment,
            importKind: importKind,
            sourceFileURL: sourceFileURL
        )
        document.blocks.append(block)
        selectedBlockID = block.id
        visibleBlockControlsID = block.id
        activeBlockID = nil
    }
}
