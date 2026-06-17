import SwiftUI

extension NativeRichEditorViewModel {
    func applyHighlight(color: String, colorName: String? = nil) {
        applyInlineAttributes { attributes in
            attributes[NativeEditorHighlightColorAttribute.self] = color
            attributes[NativeEditorHighlightColorNameAttribute.self] = colorName
            attributes.backgroundColor = Color(docmostlyHex: color)
        }
    }

    func applyTextColor(_ color: String) {
        applyInlineAttributes { attributes in
            attributes[NativeEditorTextColorAttribute.self] = color
            attributes.foregroundColor = Color(docmostlyHex: color)
        }
    }

    func applyInlineComment(commentID: String, isResolved: Bool = false) {
        let trimmedCommentID = commentID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCommentID.isEmpty == false else { return }

        applyInlineAttributes { attributes in
            attributes[NativeEditorCommentIDAttribute.self] = trimmedCommentID
            attributes[NativeEditorCommentResolvedAttribute.self] = isResolved
            attributes.backgroundColor = .yellow.opacity(0.28)
        }
    }

    func insertStatusBadge(text: String, color: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.isEmpty == false else { return }

        let status = NativeEditorStatusBadge(text: trimmedText, color: color)
        var segment = AttributedString(trimmedText)
        segment[NativeEditorStatusAttribute.self] = status
        segment.inlinePresentationIntent = .stronglyEmphasized
        insertInlineSegment(segment)
    }

    func insertMention(_ mention: NativeEditorMention) {
        var segment = AttributedString(mention.displayText)
        segment[NativeEditorMentionAttribute.self] = mention
        segment.foregroundColor = DocmostlyTheme.primary
        insertInlineSegment(segment)
    }

    func insertInlineMath(_ text: String) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.isEmpty == false else { return }

        let math = NativeEditorMathInline(text: trimmedText)
        var segment = AttributedString(trimmedText)
        segment[NativeEditorMathInlineAttribute.self] = math
        segment.inlinePresentationIntent = .code
        insertInlineSegment(segment)
    }

    private func applyInlineAttributes(_ update: (inout AttributeContainer) -> Void) {
        performUndoableEdit {
            guard let index = activeBlockIndex else { return }

            if document.blocks[index].selection.hasSelectedRanges(in: document.blocks[index].text) {
                var selection = document.blocks[index].selection
                document.blocks[index].text.transformAttributes(in: &selection) { attributes in
                    update(&attributes)
                }
                document.blocks[index].selection = selection
            } else {
                var attributes = AttributeContainer()
                update(&attributes)
                document.blocks[index].text.mergeAttributes(attributes)
            }
        }
    }

    private func insertInlineSegment(_ segment: AttributedString) {
        performUndoableEdit {
            guard let index = activeBlockIndex else { return }

            switch document.blocks[index].selection.indices(in: document.blocks[index].text) {
            case .ranges(let ranges):
                if let range = ranges.ranges.first {
                    document.blocks[index].text.replaceSubrange(range, with: segment)
                } else {
                    document.blocks[index].text.insert(segment, at: document.blocks[index].text.endIndex)
                }
            case .insertionPoint(let insertionIndex):
                document.blocks[index].text.insert(segment, at: insertionIndex)
            }

            document.blocks[index].selection = AttributedTextSelection()
        }
    }
}
