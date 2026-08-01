import Foundation
import SwiftUI

extension NativeRichEditorViewModel {
    func setActiveBlockKind(_ kind: NativeEditorBlockKind) {
        performUndoableEdit {
            guard let index = activeBlockIndex else { return }
            document.blocks[index].kind = kind
        }
    }

    func applySlashCommand(_ command: NativeEditorCommand, now: Date = .now) {
        if applyInlineSlashCommand(command, now: now) {
            return
        }

        let slashContext = activeSlashCommandContext
        performUndoableEdit {
            guard let index = activeBlockIndex else { return }

            if let replacementBlock = command.replacementBlock(reusing: document.blocks[index].id) {
                if let slashContext, slashContext.range.lowerBound != document.blocks[index].text.startIndex {
                    document.blocks[index].text.replaceSubrange(slashContext.range, with: AttributedString(""))
                    let insertedBlock = command.replacementBlock(reusing: UUID()) ?? replacementBlock
                    let insertionIndex = document.blocks.index(after: index)
                    document.blocks.insert(insertedBlock, at: insertionIndex)
                    activeBlockID = insertedBlock.id
                    return
                }

                document.blocks[index] = replacementBlock
                return
            }

            document.blocks[index].kind = command.blockKind
            if let slashContext {
                document.blocks[index].text.replaceSubrange(slashContext.range, with: AttributedString(""))
                document.blocks[index].selection = AttributedTextSelection()
            }
        }
    }

    func applyServerBackedBaseSlashCommand(
        _ command: NativeEditorCommand,
        createBasePageID: (String, DocmostBaseTemplate?) async throws -> String
    ) async {
        guard command.requiresServerBackedBaseCreation else {
            applySlashCommand(command)
            return
        }

        let pendingKey = UUID().uuidString
        guard let blockID = insertBasePlaceholder(for: command, pendingKey: pendingKey) else { return }

        do {
            let createdPageID = try await createBasePageID(currentPageID, command.baseCreationTemplate)
            updateCreatedBasePlaceholder(blockID: blockID, pageID: createdPageID)
        } catch {
            removeFailedBasePlaceholder(blockID: blockID, pendingKey: pendingKey)
            saveErrorMessage = error.localizedDescription
        }
    }

    private func insertBasePlaceholder(for command: NativeEditorCommand, pendingKey: String) -> UUID? {
        let slashContext = activeSlashCommandContext
        var insertedBlockID: UUID?

        performUndoableEdit {
            guard
                let index = activeBlockIndex,
                let replacementBlock = command.serverBackedBaseReplacementBlock(
                    reusing: document.blocks[index].id,
                    pendingKey: pendingKey
                )
            else {
                return
            }

            if let slashContext, slashContext.range.lowerBound != document.blocks[index].text.startIndex {
                document.blocks[index].text.replaceSubrange(slashContext.range, with: AttributedString(""))
                let insertedBlock = command.serverBackedBaseReplacementBlock(
                    reusing: UUID(),
                    pendingKey: pendingKey
                ) ?? replacementBlock
                let insertionIndex = document.blocks.index(after: index)
                document.blocks.insert(insertedBlock, at: insertionIndex)
                activeBlockID = insertedBlock.id
                insertedBlockID = insertedBlock.id
                return
            }

            document.blocks[index] = replacementBlock
            insertedBlockID = replacementBlock.id
        }

        return insertedBlockID
    }

    private func updateCreatedBasePlaceholder(blockID: UUID, pageID: String) {
        performUndoableEdit {
            guard
                let index = document.blocks.firstIndex(where: { $0.id == blockID }),
                case .base(var base) = document.blocks[index].kind
            else {
                return
            }

            base.pageID = pageID
            base.pendingKey = nil
            document.blocks[index].kind = .base(base)
            document.blocks[index].rawNode = NativeEditorRichBlockNodeFactory.baseNode(from: base)
            document.blocks[index].text = AttributedString(base.previewText)
        }
    }

    private func removeFailedBasePlaceholder(blockID: UUID, pendingKey: String) {
        performUndoableEdit {
            guard
                let index = document.blocks.firstIndex(where: { $0.id == blockID }),
                case .base(let base) = document.blocks[index].kind,
                base.pendingKey == pendingKey
            else {
                return
            }

            document.blocks.remove(at: index)
            if document.blocks.isEmpty {
                document.blocks.append(
                    NativeEditorBlock(kind: .paragraph, text: AttributedString(""), alignment: .left)
                )
            }
            activeBlockID = document.blocks[min(index, document.blocks.count - 1)].id
        }
    }

    @discardableResult
    private func applyInlineSlashCommand(_ command: NativeEditorCommand, now: Date) -> Bool {
        guard let segment = inlineSegment(for: command, now: now) else { return false }

        let slashContext = activeSlashCommandContext
        performUndoableEdit {
            guard let index = activeBlockIndex else { return }

            if let slashContext {
                document.blocks[index].text.replaceSubrange(slashContext.range, with: segment)
            } else {
                insert(segment, into: &document.blocks[index])
            }

            document.blocks[index].selection = AttributedTextSelection()
        }

        return true
    }

    private func inlineSegment(for command: NativeEditorCommand, now: Date) -> AttributedString? {
        switch command {
        case .date:
            AttributedString(now.formatted(date: .long, time: .omitted))
        case .time:
            AttributedString(now.formatted(date: .omitted, time: .shortened))
        case .status:
            statusSegment(text: "", color: "gray")
        case .emoji:
            AttributedString(":")
        case .mathInline:
            mathInlineSegment(text: "")
        default:
            nil
        }
    }

    private func statusSegment(text: String, color: String) -> AttributedString {
        let status = NativeEditorStatusBadge(text: text, color: color)
        var segment = AttributedString(status.displayText)
        segment[NativeEditorStatusAttribute.self] = status
        segment.inlinePresentationIntent = .stronglyEmphasized
        return segment
    }

    private func mathInlineSegment(text: String) -> AttributedString {
        let math = NativeEditorMathInline(text: text)
        var segment = AttributedString(math.displayText)
        segment[NativeEditorMathInlineAttribute.self] = math
        segment.inlinePresentationIntent = .code
        return segment
    }

    private func insert(_ segment: AttributedString, into block: inout NativeEditorBlock) {
        switch block.selection.indices(in: block.text) {
        case .ranges(let ranges):
            if let range = ranges.ranges.first {
                block.text.replaceSubrange(range, with: segment)
            } else {
                block.text.insert(segment, at: block.text.endIndex)
            }
        case .insertionPoint(let insertionIndex):
            block.text.insert(segment, at: insertionIndex)
        }
    }

    func setActiveAlignment(_ alignment: NativeEditorTextAlignment) {
        performUndoableEdit {
            guard let index = activeBlockIndex else { return }
            document.blocks[index].alignment = alignment
        }
    }

    func toggleInlineMark(_ mark: NativeEditorInlineMark) {
        guard let index = activeBlockIndex else { return }

        let block = document.blocks[index]
        guard block.selection.hasSelectedRanges(in: block.text) else {
            var marks = inlineTypingContext?.blockID == block.id
                ? inlineTypingContext?.marks ?? []
                : NativeEditorInlineMark.activeMarks(for: block.selection, in: block.text)
            if marks.contains(mark) {
                marks.remove(mark)
            } else {
                if mark == .subscript {
                    marks.remove(.superscript)
                } else if mark == .superscript {
                    marks.remove(.subscript)
                }
                marks.insert(mark)
            }
            inlineTypingContext = NativeEditorInlineTypingContext(blockID: block.id, marks: marks)
            return
        }

        inlineTypingContext = nil
        performUndoableEdit {
            var selection = document.blocks[index].selection
            document.blocks[index].text.transformAttributes(in: &selection) { attributes in
                mark.toggle(in: &attributes)
            }
            document.blocks[index].selection = selection
        }
    }

    func isInlineMarkActive(_ mark: NativeEditorInlineMark) -> Bool {
        guard let index = activeBlockIndex else { return false }
        let block = document.blocks[index]
        if block.selection.hasSelectedRanges(in: block.text) == false,
           inlineTypingContext?.blockID == block.id {
            return inlineTypingContext?.marks.contains(mark) == true
        }
        return NativeEditorInlineMark.activeMarks(for: block.selection, in: block.text).contains(mark)
    }

    func typingInlineMarks(for blockID: UUID) -> Set<NativeEditorInlineMark> {
        guard let block = document.blocks.first(where: { $0.id == blockID }) else { return [] }
        if block.selection.hasSelectedRanges(in: block.text) == false,
           inlineTypingContext?.blockID == block.id {
            return inlineTypingContext?.marks ?? []
        }
        return NativeEditorInlineMark.activeMarks(for: block.selection, in: block.text)
    }

    func invalidateInlineTypingContext(for blockID: UUID) {
        guard inlineTypingContext?.blockID == blockID else { return }
        inlineTypingContext = nil
    }

    func applyLink(_ urlString: String) {
        performUndoableEdit {
            guard
                let index = activeBlockIndex,
                let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines))
            else {
                return
            }
            let link = NativeEditorLink(href: url.absoluteString, isInternal: false)

            if document.blocks[index].selection.hasSelectedRanges(in: document.blocks[index].text) {
                var selection = document.blocks[index].selection
                document.blocks[index].text.transformAttributes(in: &selection) { attributes in
                    attributes.link = url
                    attributes[NativeEditorLinkAttribute.self] = link
                }
                document.blocks[index].selection = selection
            } else {
                document.blocks[index].text.link = url
                document.blocks[index].text[NativeEditorLinkAttribute.self] = link
            }
        }
    }

    func removeLink() {
        performUndoableEdit {
            guard let index = activeBlockIndex else { return }

            if document.blocks[index].selection.hasSelectedRanges(in: document.blocks[index].text) {
                var selection = document.blocks[index].selection
                document.blocks[index].text.transformAttributes(in: &selection) { attributes in
                    attributes.link = nil
                    attributes[NativeEditorLinkAttribute.self] = nil
                }
                document.blocks[index].selection = selection
            } else {
                document.blocks[index].text.link = nil
                document.blocks[index].text[NativeEditorLinkAttribute.self] = nil
            }
        }
    }

    func appendBlock() {
        performUndoableEdit {
            document.blocks.append(NativeEditorBlock(kind: .paragraph, text: AttributedString(""), alignment: .left))
            activeBlockID = document.blocks.last?.id
        }
    }

    func insertBlock(after blockID: UUID) {
        performUndoableEdit {
            guard let index = document.blocks.firstIndex(where: { $0.id == blockID }) else {
                document.blocks.append(
                    NativeEditorBlock(kind: .paragraph, text: AttributedString(""), alignment: .left)
                )
                activeBlockID = document.blocks.last?.id
                return
            }

            let nextIndex = document.blocks.index(after: index)
            let block = NativeEditorBlock(kind: .paragraph, text: AttributedString(""), alignment: .left)
            document.blocks.insert(block, at: nextIndex)
            activeBlockID = block.id
        }
    }

    @discardableResult
    func deleteBlock(_ blockID: UUID) -> UUID? {
        var destinationBlockID: UUID?
        performUndoableEdit {
            guard let index = document.blocks.firstIndex(where: { $0.id == blockID }) else { return }
            let deletedBlockWasSelected = selectedBlockID == blockID

            if document.blocks.count == 1 {
                document.blocks[0].text = AttributedString("")
                document.blocks[0].kind = .paragraph
                document.blocks[0].alignment = .left
                document.blocks[0].indentLevel = 0
            } else {
                document.blocks.remove(at: index)
            }

            if deletedBlockWasSelected {
                selectedBlockID = nil
            }
            if visibleBlockControlsID == blockID {
                visibleBlockControlsID = nil
            }

            destinationBlockID = focusEditableBlockAfterDeletion(at: index)
        }
        return destinationBlockID
    }

    private func focusEditableBlockAfterDeletion(at deletedIndex: Int) -> UUID? {
        guard document.blocks.isEmpty == false else {
            activeBlockID = nil
            return nil
        }

        let precedingIndices = document.blocks.indices.prefix(min(deletedIndex, document.blocks.count)).reversed()
        let followingIndices = document.blocks.indices.dropFirst(min(deletedIndex, document.blocks.count))
        let focusIndex = precedingIndices.first(where: { document.blocks[$0].isEditable }) ??
            followingIndices.first(where: { document.blocks[$0].isEditable })
        guard let focusIndex else {
            activeBlockID = nil
            return nil
        }

        let insertionOffset = focusIndex < deletedIndex ? document.blocks[focusIndex].text.characters.count : 0
        let insertionIndex = document.blocks[focusIndex].text.characters.index(
            document.blocks[focusIndex].text.startIndex,
            offsetBy: insertionOffset
        )
        document.blocks[focusIndex].selection = AttributedTextSelection(insertionPoint: insertionIndex)
        activeBlockID = document.blocks[focusIndex].id
        return activeBlockID
    }

    @discardableResult
    func deleteSelectedBlock() -> UUID? {
        guard let selectedBlockID else { return nil }
        return deleteBlock(selectedBlockID)
    }

    func moveBlock(_ blockID: UUID, before targetBlockID: UUID) {
        performUndoableEdit {
            guard
                blockID != targetBlockID,
                let sourceIndex = document.blocks.firstIndex(where: { $0.id == blockID }),
                document.blocks.contains(where: { $0.id == targetBlockID })
            else {
                return
            }

            let block = document.blocks.remove(at: sourceIndex)
            guard let targetIndex = document.blocks.firstIndex(where: { $0.id == targetBlockID }) else {
                document.blocks.insert(block, at: sourceIndex)
                return
            }

            document.blocks.insert(block, at: targetIndex)
        }
    }

    var activeBlockIndex: Array<NativeEditorBlock>.Index? {
        guard canEdit else { return nil }
        guard let activeBlockID else { return nil }
        return document.blocks.firstIndex { $0.id == activeBlockID && $0.isEditable }
    }

    var activeSlashCommandQuery: String? {
        activeSlashCommandContext?.query
    }

    private var activeSlashCommandContext: NativeEditorSlashCommandContext? {
        guard let index = activeBlockIndex else { return nil }
        guard document.blocks[index].kind.allowsSlashCommands else { return nil }

        let block = document.blocks[index]
        let insertionIndex: AttributedString.Index
        switch block.selection.indices(in: block.text) {
        case .ranges(let ranges):
            guard ranges.isEmpty else { return nil }
            insertionIndex = block.text.endIndex
        case .insertionPoint(let index):
            insertionIndex = index
        }

        let prefix = String(block.text.characters[..<insertionIndex])
        guard let slashIndex = prefix.lastIndex(of: "/") else {
            return nil
        }
        guard slashCommandTriggerHasAllowedPrefix(slashIndex, in: prefix) else {
            return nil
        }

        let queryStartIndex = prefix.index(after: slashIndex)
        let rawQuery = String(prefix[queryStartIndex...])
        guard rawQuery.contains("\n") == false else { return nil }

        let slashOffset = prefix.distance(from: prefix.startIndex, to: slashIndex)
        let slashTextIndex = block.text.characters.index(block.text.startIndex, offsetBy: slashOffset)
        return NativeEditorSlashCommandContext(
            query: rawQuery.trimmingCharacters(in: .whitespacesAndNewlines),
            range: slashTextIndex..<insertionIndex
        )
    }

    private func slashCommandTriggerHasAllowedPrefix(_ slashIndex: String.Index, in text: String) -> Bool {
        guard slashIndex != text.startIndex else { return true }
        return text[text.index(before: slashIndex)] == " "
    }
}

private struct NativeEditorSlashCommandContext {
    var query: String
    var range: Range<AttributedString.Index>
}

private extension NativeEditorBlockKind {
    var allowsSlashCommands: Bool {
        switch self {
        case .codeBlock:
            false
        default:
            isEditable
        }
    }
}
