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

        performUndoableEdit {
            guard let index = activeBlockIndex else { return }

            if let replacementBlock = command.replacementBlock(reusing: document.blocks[index].id) {
                document.blocks[index] = replacementBlock
                return
            }

            document.blocks[index].kind = command.blockKind
            if activeSlashCommandQuery != nil {
                document.blocks[index].text = AttributedString("")
                document.blocks[index].selection = AttributedTextSelection()
            }
        }
    }

    @discardableResult
    private func applyInlineSlashCommand(_ command: NativeEditorCommand, now: Date) -> Bool {
        guard let segment = inlineSegment(for: command, now: now) else { return false }

        performUndoableEdit {
            guard let index = activeBlockIndex else { return }

            if activeSlashCommandQuery != nil {
                document.blocks[index].text = segment
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

            if document.blocks[index].selection.hasSelectedRanges(in: document.blocks[index].text) {
                var selection = document.blocks[index].selection
                document.blocks[index].text.transformAttributes(in: &selection) { attributes in
                    attributes.link = url
                }
                document.blocks[index].selection = selection
            } else {
                document.blocks[index].text.link = url
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
                }
                document.blocks[index].selection = selection
            } else {
                document.blocks[index].text.link = nil
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
        guard let index = activeBlockIndex else { return nil }
        guard document.blocks[index].kind.allowsSlashCommands else { return nil }

        let text = String(document.blocks[index].text.characters)
        guard text.first == "/", text.contains("\n") == false else {
            return nil
        }

        return String(text.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
    }
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
