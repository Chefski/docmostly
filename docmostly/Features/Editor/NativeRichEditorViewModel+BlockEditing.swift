import Foundation
import SwiftUI

extension NativeRichEditorViewModel {
    func setActiveBlockKind(_ kind: NativeEditorBlockKind) {
        performUndoableEdit {
            guard let index = activeBlockIndex else { return }
            document.blocks[index].kind = kind
        }
    }

    func applySlashCommand(_ command: NativeEditorCommand) {
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

        let text = String(document.blocks[index].text.characters)
        guard text.first == "/", text.contains("\n") == false else {
            return nil
        }

        return String(text.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
