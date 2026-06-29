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
            statusSegment(text: "Status", color: "gray")
        case .emoji:
            AttributedString(":")
        case .mathInline:
            mathInlineSegment(text: "x = y")
        default:
            nil
        }
    }

    private func statusSegment(text: String, color: String) -> AttributedString {
        let status = NativeEditorStatusBadge(text: text, color: color)
        var segment = AttributedString(text)
        segment[NativeEditorStatusAttribute.self] = status
        segment.inlinePresentationIntent = .stronglyEmphasized
        return segment
    }

    private func mathInlineSegment(text: String) -> AttributedString {
        let math = NativeEditorMathInline(text: text)
        var segment = AttributedString(text)
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
        performUndoableEdit {
            guard let index = activeBlockIndex else { return }

            if document.blocks[index].selection.hasSelectedRanges(in: document.blocks[index].text) {
                var selection = document.blocks[index].selection
                document.blocks[index].text.transformAttributes(in: &selection) { attributes in
                    mark.toggle(in: &attributes)
                }
                document.blocks[index].selection = selection
            } else {
                mark.toggle(in: &document.blocks[index].text)
            }
        }
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

    func deleteBlock(_ blockID: UUID) {
        performUndoableEdit {
            guard let index = document.blocks.firstIndex(where: { $0.id == blockID }) else { return }

            if document.blocks.count == 1 {
                document.blocks[0].text = AttributedString("")
                document.blocks[0].kind = .paragraph
                document.blocks[0].alignment = .left
                document.blocks[0].indentLevel = 0
            } else {
                document.blocks.remove(at: index)
            }

            if activeBlockID == blockID {
                activeBlockID = document.blocks.indices.contains(index) ?
                    document.blocks[index].id :
                    document.blocks.last?.id
            }

            if selectedBlockID == blockID {
                selectedBlockID = nil
                visibleBlockControlsID = nil
                activeBlockID = document.blocks.indices.contains(index) ?
                    document.blocks[index].id :
                    document.blocks.last?.id
            }
        }
    }

    func deleteSelectedBlock() {
        guard let selectedBlockID else { return }
        deleteBlock(selectedBlockID)
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
