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

        let attachmentsWithDimensions = await attachments.orderedConcurrentMap { uploadedAttachment in
            (
                attachment: uploadedAttachment.attachment,
                sourceFileURL: uploadedAttachment.sourceFileURL,
                mediaDimensions: await NativeEditorAttachmentBlockFactory.mediaDimensions(
                    for: uploadedAttachment.sourceFileURL,
                    importKind: importKind
                )
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

private extension Sequence where Element: Sendable {
    func orderedConcurrentMap<Transformed: Sendable>(
        _ transform: @escaping @Sendable (Element) async -> Transformed
    ) async -> [Transformed] {
        let elements = Array(self)
        return await withTaskGroup(
            of: (offset: Int, value: Transformed).self,
            returning: [Transformed].self
        ) { group in
            for (offset, element) in elements.enumerated() {
                group.addTask {
                    (offset, await transform(element))
                }
            }

            var values = [Transformed?](repeating: nil, count: elements.count)
            for await result in group {
                values[result.offset] = result.value
            }

            return values.compactMap(\.self)
        }
    }
}
