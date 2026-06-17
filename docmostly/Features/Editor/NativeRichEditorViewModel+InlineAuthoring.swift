import SwiftUI

extension NativeRichEditorViewModel {
    var activeSelectedPlainText: String? {
        activeInlineCommentContext?.selectedText
    }

    var activeInlineCommentContext: NativeEditorInlineCommentContext? {
        guard let index = activeBlockIndex else { return nil }

        let block = document.blocks[index]
        guard let selectedText = selectedPlainText(in: block, selection: block.selection) else {
            return nil
        }

        return NativeEditorInlineCommentContext(
            blockID: block.id,
            selectedText: selectedText,
            selection: block.selection
        )
    }

    private func selectedPlainText(
        in block: NativeEditorBlock,
        selection: AttributedTextSelection
    ) -> String? {
        guard selection.hasSelectedRanges(in: block.text) else { return nil }

        let selectedText: String
        switch selection.indices(in: block.text) {
        case .ranges(let ranges):
            selectedText = ranges.ranges
                .map { String(block.text[$0].characters) }
                .joined(separator: " ")
        case .insertionPoint:
            selectedText = ""
        }

        let trimmedText = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedText.isEmpty ? nil : trimmedText
    }

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

    func applyInlineComment(
        commentID: String,
        to context: NativeEditorInlineCommentContext,
        isResolved: Bool = false
    ) {
        let trimmedCommentID = commentID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCommentID.isEmpty == false else { return }

        performUndoableEdit {
            guard let index = document.blocks.firstIndex(where: { $0.id == context.blockID }) else { return }

            var selection = context.selection
            guard selection.hasSelectedRanges(in: document.blocks[index].text) else { return }

            document.blocks[index].text.transformAttributes(in: &selection) { attributes in
                attributes[NativeEditorCommentIDAttribute.self] = trimmedCommentID
                attributes[NativeEditorCommentResolvedAttribute.self] = isResolved
                attributes.backgroundColor = .yellow.opacity(0.28)
            }
            document.blocks[index].selection = selection
            activeBlockID = context.blockID
        }
    }

    func setInlineCommentResolved(commentID: String, isResolved: Bool, tracksUndo: Bool = true) {
        let trimmedCommentID = commentID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCommentID.isEmpty == false else { return }

        var updatedDocument = document
        guard Self.updateInlineCommentResolved(
            commentID: trimmedCommentID,
            isResolved: isResolved,
            in: &updatedDocument
        ) else { return }

        if tracksUndo {
            performUndoableEdit {
                document = updatedDocument
            }
        } else {
            document = updatedDocument
            _ = Self.updateInlineCommentResolved(
                commentID: trimmedCommentID,
                isResolved: isResolved,
                in: &lastSavedDocument
            )
            lastKnownSnapshot = makeHistorySnapshot()
            recalculateDirty()
        }
    }

    private static func updateInlineCommentResolved(
        commentID: String,
        isResolved: Bool,
        in document: inout NativeEditorDocument
    ) -> Bool {
        var didUpdate = false

        for index in document.blocks.indices {
            let ranges = document.blocks[index].text.runs.compactMap { run in
                run[NativeEditorCommentIDAttribute.self] == commentID ? run.range : nil
            }
            guard ranges.isEmpty == false else { continue }

            didUpdate = true
            for range in ranges {
                document.blocks[index].text[range][NativeEditorCommentResolvedAttribute.self] = isResolved
                document.blocks[index].text[range].backgroundColor = isResolved
                    ? .gray.opacity(0.16)
                    : .yellow.opacity(0.28)
            }
        }

        return didUpdate
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
