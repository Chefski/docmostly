import Foundation

extension NativeRichEditorViewModel {
    func insertUploadedAttachment(
        _ attachment: DocmostAttachment,
        as importKind: NativeEditorAttachmentImportKind,
        sourceFileURL: URL? = nil
    ) async {
        let mediaDimensions = await NativeEditorAttachmentBlockFactory.mediaDimensions(
            for: sourceFileURL,
            importKind: importKind
        )

        performUndoableEdit {
            insertUploadedAttachmentInCurrentDocument(
                attachment,
                as: importKind,
                sourceFileURL: sourceFileURL,
                mediaDimensions: mediaDimensions
            )
        }
    }

    func insertUploadedAttachments(
        _ attachments: [(attachment: DocmostAttachment, sourceFileURL: URL?)],
        as importKind: NativeEditorAttachmentImportKind
    ) async {
        guard attachments.isEmpty == false else { return }

        let attachmentsWithDimensions = await attachments.asyncMap { uploadedAttachment in
            let mediaDimensions = await NativeEditorAttachmentBlockFactory.mediaDimensions(
                for: uploadedAttachment.sourceFileURL,
                importKind: importKind
            )
            return (
                attachment: uploadedAttachment.attachment,
                sourceFileURL: uploadedAttachment.sourceFileURL,
                mediaDimensions: mediaDimensions
            )
        }

        performUndoableEdit {
            for uploadedAttachment in attachmentsWithDimensions {
                insertUploadedAttachmentInCurrentDocument(
                    uploadedAttachment.attachment,
                    as: importKind,
                    sourceFileURL: uploadedAttachment.sourceFileURL,
                    mediaDimensions: uploadedAttachment.mediaDimensions
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
        sourceFileURL: URL? = nil,
        mediaDimensions: NativeEditorMediaDimensions?
    ) {
        if let index = activeBlockIndex {
            let block = NativeEditorAttachmentBlockFactory.block(
                for: attachment,
                importKind: importKind,
                replacing: document.blocks[index].id,
                sourceFileURL: sourceFileURL,
                mediaDimensions: mediaDimensions
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
                sourceFileURL: sourceFileURL,
                mediaDimensions: mediaDimensions
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
            sourceFileURL: sourceFileURL,
            mediaDimensions: mediaDimensions
        )
        document.blocks.append(block)
        selectedBlockID = block.id
        visibleBlockControlsID = block.id
        activeBlockID = nil
    }
}

private extension Sequence {
    func asyncMap<Transformed>(
        _ transform: (Element) async -> Transformed
    ) async -> [Transformed] {
        var values: [Transformed] = []
        values.reserveCapacity(underestimatedCount)

        for element in self {
            values.append(await transform(element))
        }

        return values
    }
}
