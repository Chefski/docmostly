import Foundation
import SwiftUI

extension NativeRichEditorViewModel {
    func pasteMarkdown(_ markdown: String) {
        let pastedBlocks = NativeEditorMarkdownParser.blocks(from: markdown)
        guard pastedBlocks.isEmpty == false else { return }

        performUndoableEdit {
            if let placeholderIndex = singleEmptyPlaceholderPasteIndex() {
                document.blocks.replaceSubrange(placeholderIndex...placeholderIndex, with: pastedBlocks)
            } else {
                let insertionIndex = markdownPasteIndex()
                document.blocks.insert(contentsOf: pastedBlocks, at: insertionIndex)
            }
            activeBlockID = pastedBlocks.last?.id
            selectedBlockID = nil
            visibleBlockControlsID = nil
        }
    }

    func dropMarkdown(_ markdown: String, before targetBlockID: UUID) -> Bool {
        guard canEdit else { return false }
        let droppedBlocks = NativeEditorMarkdownParser.blocks(from: markdown)
        guard
            droppedBlocks.isEmpty == false,
            let targetIndex = document.blocks.firstIndex(where: { $0.id == targetBlockID })
        else {
            return false
        }

        performUndoableEdit {
            document.blocks.insert(contentsOf: droppedBlocks, at: targetIndex)
            activeBlockID = droppedBlocks.last?.id
            selectedBlockID = nil
            visibleBlockControlsID = nil
        }
        return true
    }

    func indentActiveBlock() {
        adjustActiveBlockIndent(by: 1)
    }

    func outdentActiveBlock() {
        adjustActiveBlockIndent(by: -1)
    }

    func markdownForDocument() -> String {
        NativeEditorMarkdownParser.markdown(from: document.blocks)
    }

    func markdownForActiveBlock() -> String {
        guard
            let activeBlockID,
            let block = document.blocks.first(where: { $0.id == activeBlockID })
        else {
            return markdownForDocument()
        }

        return NativeEditorMarkdownParser.markdown(from: [block])
    }

    func copyActiveBlockMarkdownToClipboard() {
        NativeEditorClipboard.write(markdownForActiveBlock())
    }

    func applyMarkdownInputRuleIfNeeded() {
        guard
            let index = activeBlockIndex,
            let rule = NativeEditorMarkdownParser.inputRule(
                from: String(document.blocks[index].text.characters)
            )
        else {
            return
        }

        document.blocks[index].kind = rule.kind
        document.blocks[index].text = AttributedString(rule.text)
        document.blocks[index].selection = AttributedTextSelection()
    }

    func applyInlineMarkdownInputRuleIfNeeded() {
        guard
            let index = activeBlockIndex,
            document.blocks[index].kind.allowsInlineMarkdownInputRules,
            let attributedText = NativeEditorMarkdownParser.inlineMarkdownInputRuleText(
                from: String(document.blocks[index].text.characters)
            )
        else {
            return
        }

        document.blocks[index].text = attributedText
        document.blocks[index].selection = AttributedTextSelection()
    }

    func applySmartTypographyIfNeeded() {
        guard let index = activeBlockIndex, document.blocks[index].kind.allowsSmartTypography else { return }

        let text = String(document.blocks[index].text.characters)
        let transformedText = NativeEditorSmartTypography.transform(text)
        guard transformedText != text else { return }

        document.blocks[index].text = AttributedString(transformedText)
    }

    private func markdownPasteIndex() -> Array<NativeEditorBlock>.Index {
        guard
            let activeBlockID,
            let index = document.blocks.firstIndex(where: { $0.id == activeBlockID })
        else {
            return document.blocks.endIndex
        }

        return document.blocks.index(after: index)
    }

    private func singleEmptyPlaceholderPasteIndex() -> Array<NativeEditorBlock>.Index? {
        guard document.blocks.count == 1,
              let index = document.blocks.indices.first,
              activeBlockID == document.blocks[index].id,
              document.blocks[index].kind == .paragraph,
              document.blocks[index].inlineContent == nil
        else {
            return nil
        }

        let text = String(document.blocks[index].text.characters).trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? index : nil
    }

    private func adjustActiveBlockIndent(by delta: Int) {
        performUndoableEdit {
            guard let index = activeBlockIndex, document.blocks[index].kind.isListItem else { return }

            let nextIndentLevel = max(0, min(8, document.blocks[index].indentLevel + delta))
            document.blocks[index].indentLevel = nextIndentLevel
        }
    }
}

private extension NativeEditorBlockKind {
    var isListItem: Bool {
        switch self {
        case .bulletListItem, .orderedListItem, .taskListItem:
            true
        default:
            false
        }
    }

    var allowsSmartTypography: Bool {
        switch self {
        case .codeBlock:
            false
        default:
            true
        }
    }

    var allowsInlineMarkdownInputRules: Bool {
        switch self {
        case .codeBlock:
            false
        default:
            isEditable
        }
    }
}
