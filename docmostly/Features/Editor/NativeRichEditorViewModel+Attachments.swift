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
}
