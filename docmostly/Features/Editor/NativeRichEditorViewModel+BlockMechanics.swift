import Foundation
import SwiftUI

extension NativeRichEditorViewModel {
    @discardableResult
    func splitBlock(_ blockID: UUID, at characterOffset: Int) -> UUID? {
        splitBlock(blockID, replacing: characterOffset..<characterOffset)
    }

    @discardableResult
    func splitBlock(_ blockID: UUID, replacing characterRange: Range<Int>) -> UUID? {
        guard let index = editableBlockIndex(for: blockID) else { return nil }
        if document.blocks[index].kind.isMechanicsListItem {
            return continueListItem(blockID, replacing: characterRange)
        }

        var resultingBlockID: UUID?
        performUndoableEdit {
            guard let index = editableBlockIndex(for: blockID) else { return }

            var block = document.blocks[index]
            // ProseMirror handles an empty quote with liftEmptyBlock before it attempts a split.
            if block.kind.exitsEmptyContainerOnReturn,
               block.text.characters.isEmpty,
               characterRange.isEmpty {
                guard Self.canLiftEmptyBlockquote(block) else { return }

                let liftedRawNode = Self.rawNodeAfterLiftingEmptyBlockquote(block)
                block.kind = .paragraph
                block.alignment = .left
                block.indentLevel = 0
                block.rawNode = liftedRawNode
                Self.setInsertionPoint(at: 0, in: &block)
                document.blocks[index] = block
                activateBlockAfterMechanicsEdit(block.id)
                resultingBlockID = block.id
                return
            }

            let split = Self.splitText(block.text, replacing: characterRange)
            let continuationKind = block.kind.mechanicsContinuationKind(
                hasTrailingText: split.trailing.characters.isEmpty == false
            )
            let preservesBlockStyle = continuationKind == block.kind
            let leadingText = if block.kind.isMechanicsCodeBlock,
                                 characterRange.isEmpty,
                                 split.trailing.characters.isEmpty {
                Self.removingTrailingCodeExitNewlines(from: split.leading)
            } else {
                split.leading
            }

            block.text = leadingText
            Self.setInsertionPoint(at: block.text.characters.count, in: &block)
            document.blocks[index] = block

            var continuation = NativeEditorBlock(
                kind: continuationKind,
                text: split.trailing,
                alignment: preservesBlockStyle ? block.alignment : .left,
                indentLevel: preservesBlockStyle ? block.indentLevel : 0
            )
            Self.setInsertionPoint(at: 0, in: &continuation)

            let insertionIndex = document.blocks.index(after: index)
            document.blocks.insert(continuation, at: insertionIndex)
            activateBlockAfterMechanicsEdit(continuation.id)
            resultingBlockID = continuation.id
        }
        return resultingBlockID
    }

    @discardableResult
    func continueListItem(_ blockID: UUID, at characterOffset: Int) -> UUID? {
        continueListItem(blockID, replacing: characterOffset..<characterOffset)
    }

    @discardableResult
    func continueListItem(_ blockID: UUID, replacing characterRange: Range<Int>) -> UUID? {
        var continuationBlockID: UUID?
        performUndoableEdit {
            guard
                let index = editableBlockIndex(for: blockID),
                document.blocks[index].kind.isMechanicsListItem
            else {
                return
            }

            var block = document.blocks[index]
            let split = Self.splitText(block.text, replacing: characterRange)

            if split.leading.characters.isEmpty, split.trailing.characters.isEmpty {
                guard block.indentLevel > 0 || Self.canDiscardContainerRawNode(from: block) else { return }

                block.text = AttributedString("")
                if block.indentLevel > 0 {
                    block.indentLevel -= 1
                } else {
                    block.kind = .paragraph
                    block.alignment = .left
                    block.rawNode = nil
                }
                Self.setInsertionPoint(at: 0, in: &block)
                document.blocks[index] = block
                activateBlockAfterMechanicsEdit(block.id)
                continuationBlockID = block.id
                return
            }

            let continuationKind = block.kind.mechanicsListContinuationKind
            block.text = split.leading
            Self.setInsertionPoint(at: block.text.characters.count, in: &block)
            document.blocks[index] = block

            var continuation = NativeEditorBlock(
                kind: continuationKind,
                text: split.trailing,
                alignment: block.alignment,
                indentLevel: block.indentLevel
            )
            Self.setInsertionPoint(at: 0, in: &continuation)

            let insertionIndex = document.blocks.index(after: index)
            document.blocks.insert(continuation, at: insertionIndex)
            renumberOrderedListItems(after: insertionIndex)
            activateBlockAfterMechanicsEdit(continuation.id)
            continuationBlockID = continuation.id
        }
        return continuationBlockID
    }

    @discardableResult
    func insertSoftBreak(in blockID: UUID, at characterOffset: Int) -> Bool {
        insertSoftBreak(in: blockID, replacing: characterOffset..<characterOffset)
    }

    @discardableResult
    func insertSoftBreak(in blockID: UUID, replacing characterRange: Range<Int>) -> Bool {
        var didInsert = false
        performUndoableEdit {
            guard let index = editableBlockIndex(for: blockID) else { return }

            var block = document.blocks[index]
            let range = Self.attributedRange(for: characterRange, in: block.text)
            let insertionOffset = block.text.characters.distance(from: block.text.startIndex, to: range.lowerBound)
            block.text.replaceSubrange(range, with: AttributedString("\n"))
            Self.setInsertionPoint(at: insertionOffset + 1, in: &block)
            document.blocks[index] = block
            activateBlockAfterMechanicsEdit(block.id)
            didInsert = true
        }
        return didInsert
    }

    @discardableResult
    func mergeBlockBackward(_ blockID: UUID) -> Bool {
        var didMerge = false
        performUndoableEdit {
            guard
                let index = editableBlockIndex(for: blockID),
                index > document.blocks.startIndex
            else {
                return
            }

            let previousIndex = document.blocks.index(before: index)
            guard document.blocks[previousIndex].isEditable else { return }

            var previousBlock = document.blocks[previousIndex]
            let currentBlock = document.blocks[index]
            guard Self.canMerge(currentBlock, into: previousBlock) else { return }

            let joinOffset = previousBlock.text.characters.count
            previousBlock.text += currentBlock.text
            Self.setInsertionPoint(at: joinOffset, in: &previousBlock)
            document.blocks[previousIndex] = previousBlock
            document.blocks.remove(at: index)

            if previousBlock.kind.isMechanicsOrderedListItem,
               currentBlock.kind.isMechanicsOrderedListItem,
               previousBlock.indentLevel == currentBlock.indentLevel {
                renumberOrderedListItems(after: previousIndex)
            }

            activateBlockAfterMechanicsEdit(previousBlock.id)
            didMerge = true
        }
        return didMerge
    }

    private func editableBlockIndex(for blockID: UUID) -> Array<NativeEditorBlock>.Index? {
        document.blocks.firstIndex { $0.id == blockID && $0.isEditable }
    }

    private func activateBlockAfterMechanicsEdit(_ blockID: UUID) {
        isTitleFocused = false
        activeBlockID = blockID
        selectedBlockID = nil
        visibleBlockControlsID = nil
    }

    private func renumberOrderedListItems(after index: Array<NativeEditorBlock>.Index) {
        guard
            document.blocks.indices.contains(index),
            case .orderedListItem(let ordinal) = document.blocks[index].kind
        else {
            return
        }

        let baseIndentLevel = document.blocks[index].indentLevel
        var nextOrdinal = incrementedEditorOrdinal(ordinal)
        var nextIndex = document.blocks.index(after: index)

        while nextIndex < document.blocks.endIndex {
            let block = document.blocks[nextIndex]
            guard block.kind.isMechanicsListItem, block.indentLevel >= baseIndentLevel else { break }

            if block.indentLevel == baseIndentLevel {
                guard block.kind.isMechanicsOrderedListItem else { break }
                document.blocks[nextIndex].kind = .orderedListItem(ordinal: nextOrdinal)
                nextOrdinal = incrementedEditorOrdinal(nextOrdinal)
            }
            nextIndex = document.blocks.index(after: nextIndex)
        }
    }

    private static func splitText(
        _ text: AttributedString,
        replacing characterRange: Range<Int>
    ) -> (leading: AttributedString, trailing: AttributedString) {
        let range = attributedRange(for: characterRange, in: text)
        return (
            AttributedString(text[..<range.lowerBound]),
            AttributedString(text[range.upperBound...])
        )
    }

    private static func attributedRange(
        for characterRange: Range<Int>,
        in text: AttributedString
    ) -> Range<AttributedString.Index> {
        let characterCount = text.characters.count
        let lowerOffset = min(max(characterRange.lowerBound, 0), characterCount)
        let upperOffset = min(max(characterRange.upperBound, lowerOffset), characterCount)
        let lowerBound = text.characters.index(text.startIndex, offsetBy: lowerOffset)
        let upperBound = text.characters.index(text.startIndex, offsetBy: upperOffset)
        return lowerBound..<upperBound
    }

    private static func setInsertionPoint(at characterOffset: Int, in block: inout NativeEditorBlock) {
        let offset = min(max(characterOffset, 0), block.text.characters.count)
        let index = block.text.characters.index(block.text.startIndex, offsetBy: offset)
        block.selection = AttributedTextSelection(insertionPoint: index)
    }

    private static func removingTrailingCodeExitNewlines(from text: AttributedString) -> AttributedString {
        // Docmost's Tiptap code block removes two blank sentinels when the third trailing Return exits.
        guard text.characters.count >= 2 else { return text }

        let lastIndex = text.characters.index(before: text.endIndex)
        let penultimateIndex = text.characters.index(before: lastIndex)
        guard text.characters[penultimateIndex] == "\n", text.characters[lastIndex] == "\n" else { return text }
        return AttributedString(text[..<penultimateIndex])
    }

    private static func canMerge(_ source: NativeEditorBlock, into destination: NativeEditorBlock) -> Bool {
        if case .codeBlock = destination.kind, case .codeBlock = source.kind {
            return canDiscardContainerRawNode(from: source)
        }
        if case .codeBlock = destination.kind {
            return false
        }
        return canDiscardContainerRawNode(from: source)
    }

    private static func canDiscardContainerRawNode(from block: NativeEditorBlock) -> Bool {
        guard let rawNode = block.rawNode else { return true }

        switch block.kind {
        case .paragraph, .heading, .codeBlock:
            return true
        case .blockquote:
            return rawNode.type != "blockquote" || (rawNode.content ?? []).count <= 1
        case .bulletListItem, .orderedListItem, .taskListItem:
            guard rawNode.type == "listItem" || rawNode.type == "taskItem" else { return true }
            return (rawNode.content ?? []).filter { $0.isListContainer == false }.count <= 1
        default:
            return false
        }
    }

    private static func canLiftEmptyBlockquote(_ block: NativeEditorBlock) -> Bool {
        guard canDiscardContainerRawNode(from: block) else { return false }
        guard let rawNode = block.rawNode else { return true }
        if rawNode.type == "paragraph" {
            return true
        }
        guard rawNode.type == "blockquote" else { return false }
        guard let child = rawNode.content?.first else { return true }
        return child.type == "paragraph"
    }

    private static func rawNodeAfterLiftingEmptyBlockquote(_ block: NativeEditorBlock) -> ProseMirrorNode? {
        guard let rawNode = block.rawNode else { return nil }
        if rawNode.type == "paragraph" {
            return rawNode
        }
        return rawNode.content?.first
    }
}

private extension NativeEditorBlockKind {
    var exitsEmptyContainerOnReturn: Bool {
        if case .blockquote = self {
            return true
        }
        return false
    }

    var isMechanicsListItem: Bool {
        switch self {
        case .bulletListItem, .orderedListItem, .taskListItem:
            true
        default:
            false
        }
    }

    var isMechanicsCodeBlock: Bool {
        if case .codeBlock = self {
            return true
        }
        return false
    }

    var isMechanicsOrderedListItem: Bool {
        if case .orderedListItem = self {
            return true
        }
        return false
    }

    var mechanicsListContinuationKind: NativeEditorBlockKind {
        switch self {
        case .taskListItem:
            .taskListItem(isChecked: false)
        case .orderedListItem(let ordinal):
            .orderedListItem(ordinal: incrementedEditorOrdinal(ordinal))
        default:
            self
        }
    }

    func mechanicsContinuationKind(hasTrailingText: Bool) -> NativeEditorBlockKind {
        switch self {
        case .heading where hasTrailingText == false:
            .paragraph
        case .codeBlock where hasTrailingText == false:
            .paragraph
        default:
            self
        }
    }
}

nonisolated private func incrementedEditorOrdinal(_ ordinal: Int) -> Int {
    let result = ordinal.addingReportingOverflow(1)
    return result.overflow ? Int.max : result.partialValue
}
