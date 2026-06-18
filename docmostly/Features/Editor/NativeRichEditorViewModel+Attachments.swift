import Foundation

extension NativeRichEditorViewModel {
    func insertUploadedAttachment(
        _ attachment: DocmostAttachment,
        as importKind: NativeEditorAttachmentImportKind,
        sourceFileURL: URL? = nil
    ) {
        performUndoableEdit {
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
}
