import SwiftUI

extension NativeRichEditorViewModel {
    @discardableResult
    static func updateInlineCommentResolved(
        commentID: String,
        isResolved: Bool,
        in document: inout NativeEditorDocument
    ) -> Bool {
        var didUpdate = false

        for index in document.blocks.indices {
            if updateInlineCommentResolved(
                commentID: commentID,
                isResolved: isResolved,
                in: &document.blocks[index].text
            ) {
                didUpdate = true
            }

            if updateInlineCommentResolved(
                commentID: commentID,
                isResolved: isResolved,
                in: &document.blocks[index].rawNode
            ) {
                didUpdate = true
            }

            if updateTableBlockInlineCommentResolved(
                commentID: commentID,
                isResolved: isResolved,
                block: &document.blocks[index]
            ) {
                didUpdate = true
            }
        }

        return didUpdate
    }

    @discardableResult
    static func removeInlineComment(
        commentID: String,
        from document: inout NativeEditorDocument
    ) -> Bool {
        var didUpdate = false

        for index in document.blocks.indices {
            if removeInlineComment(commentID: commentID, from: &document.blocks[index].text) {
                didUpdate = true
            }

            if removeInlineComment(commentID: commentID, from: &document.blocks[index].rawNode) {
                didUpdate = true
            }

            if removeInlineCommentFromTableBlock(commentID: commentID, block: &document.blocks[index]) {
                didUpdate = true
            }
        }

        return didUpdate
    }

    private static func updateTableBlockInlineCommentResolved(
        commentID: String,
        isResolved: Bool,
        block: inout NativeEditorBlock
    ) -> Bool {
        guard case .table(var table) = block.kind else { return false }
        guard updateInlineCommentResolved(commentID: commentID, isResolved: isResolved, in: &table) else {
            return false
        }

        replaceTableBlock(&block, with: table)
        return true
    }

    private static func removeInlineCommentFromTableBlock(
        commentID: String,
        block: inout NativeEditorBlock
    ) -> Bool {
        guard case .table(var table) = block.kind else { return false }
        guard removeInlineComment(commentID: commentID, from: &table) else { return false }

        replaceTableBlock(&block, with: table)
        return true
    }

    private static func replaceTableBlock(_ block: inout NativeEditorBlock, with table: NativeEditorTable) {
        block.kind = .table(table)
        block.rawNode = NativeEditorTableNodeFactory.node(from: table)
        block.text = AttributedString(NativeEditorDocument.previewText(for: .table(table)))
    }

    private static func updateInlineCommentResolved(
        commentID: String,
        isResolved: Bool,
        in text: inout AttributedString
    ) -> Bool {
        let ranges = text.runs.compactMap { run in
            run.hasNativeEditorInlineComment(commentID: commentID) ? run.range : nil
        }
        guard ranges.isEmpty == false else { return false }

        for range in ranges {
            let comments = text[range]
                .nativeEditorInlineComments
                .updatingNativeEditorInlineComment(NativeEditorInlineCommentMark(
                    commentID: commentID,
                    isResolved: isResolved
                ))
            text.setNativeEditorInlineComments(comments, in: range)
        }
        return true
    }

    private static func removeInlineComment(
        commentID: String,
        from text: inout AttributedString
    ) -> Bool {
        let ranges = text.runs.compactMap { run in
            run.hasNativeEditorInlineComment(commentID: commentID) ? run.range : nil
        }
        guard ranges.isEmpty == false else { return false }

        for range in ranges {
            let highlightColor = text[range][NativeEditorHighlightColorAttribute.self]
            let comments = text[range]
                .nativeEditorInlineComments
                .removingNativeEditorInlineComment(commentID: commentID)
            text.setNativeEditorInlineComments(
                comments,
                in: range,
                fallbackBackgroundColor: highlightColor.flatMap { Color(docmostlyHex: $0) }
            )
        }
        return true
    }

    private static func updateInlineCommentResolved(
        commentID: String,
        isResolved: Bool,
        in table: inout NativeEditorTable
    ) -> Bool {
        mutateTableCells(in: &table) { cell in
            updateInlineCommentResolved(commentID: commentID, isResolved: isResolved, in: &cell)
        }
    }

    private static func removeInlineComment(
        commentID: String,
        from table: inout NativeEditorTable
    ) -> Bool {
        mutateTableCells(in: &table) { cell in
            removeInlineComment(commentID: commentID, from: &cell)
        }
    }

    private static func mutateTableCells(
        in table: inout NativeEditorTable,
        mutation: (inout NativeEditorTableCell) -> Bool
    ) -> Bool {
        var didUpdate = false
        for rowIndex in table.rows.indices {
            for cellIndex in table.rows[rowIndex].cells.indices where mutation(&table.rows[rowIndex].cells[cellIndex]) {
                didUpdate = true
            }
        }
        return didUpdate
    }

    private static func updateInlineCommentResolved(
        commentID: String,
        isResolved: Bool,
        in cell: inout NativeEditorTableCell
    ) -> Bool {
        let didUpdateInlineContent = updateInlineCommentResolved(
            commentID: commentID,
            isResolved: isResolved,
            in: &cell.inlineContent
        )
        let didUpdatePreservedContent = updateInlineCommentResolved(
            commentID: commentID,
            isResolved: isResolved,
            in: &cell.preservedContent
        )
        return didUpdateInlineContent || didUpdatePreservedContent
    }

    private static func removeInlineComment(
        commentID: String,
        from cell: inout NativeEditorTableCell
    ) -> Bool {
        let didUpdateInlineContent = removeInlineComment(commentID: commentID, from: &cell.inlineContent)
        let didUpdatePreservedContent = removeInlineComment(commentID: commentID, from: &cell.preservedContent)
        return didUpdateInlineContent || didUpdatePreservedContent
    }

    private static func updateInlineCommentResolved(
        commentID: String,
        isResolved: Bool,
        in inlineContent: inout [NativeEditorInlineContent]?
    ) -> Bool {
        mutateInlineContent(&inlineContent) { marks in
            updateInlineCommentResolved(commentID: commentID, isResolved: isResolved, in: &marks)
        } unsupportedNodeMutation: { node in
            updateInlineCommentResolved(commentID: commentID, isResolved: isResolved, in: &node)
        }
    }

    private static func removeInlineComment(
        commentID: String,
        from inlineContent: inout [NativeEditorInlineContent]?
    ) -> Bool {
        mutateInlineContent(&inlineContent) { marks in
            removeInlineComment(commentID: commentID, from: &marks)
        } unsupportedNodeMutation: { node in
            removeInlineComment(commentID: commentID, from: &node)
        }
    }

    private static func mutateInlineContent(
        _ inlineContent: inout [NativeEditorInlineContent]?,
        marksMutation: (inout [NativeEditorTextMark]) -> Bool,
        unsupportedNodeMutation: (inout ProseMirrorNode) -> Bool
    ) -> Bool {
        guard var updatedContent = inlineContent else { return false }
        let didUpdate = mutateInlineContent(
            &updatedContent,
            marksMutation: marksMutation,
            unsupportedNodeMutation: unsupportedNodeMutation
        )
        guard didUpdate else { return false }

        inlineContent = updatedContent
        return true
    }

    private static func mutateInlineContent(
        _ inlineContent: inout [NativeEditorInlineContent],
        marksMutation: (inout [NativeEditorTextMark]) -> Bool,
        unsupportedNodeMutation: (inout ProseMirrorNode) -> Bool
    ) -> Bool {
        var didUpdate = false
        for index in inlineContent.indices {
            let updatedItem = mutateInlineContentItem(
                inlineContent[index],
                marksMutation: marksMutation,
                unsupportedNodeMutation: unsupportedNodeMutation
            )
            guard updatedItem.didUpdate else { continue }

            inlineContent[index] = updatedItem.content
            didUpdate = true
        }
        return didUpdate
    }

    private static func mutateInlineContentItem(
        _ content: NativeEditorInlineContent,
        marksMutation: (inout [NativeEditorTextMark]) -> Bool,
        unsupportedNodeMutation: (inout ProseMirrorNode) -> Bool
    ) -> (content: NativeEditorInlineContent, didUpdate: Bool) {
        switch content {
        case .text(let text, var marks):
            return mutateTextContent(text, marks: &marks, marksMutation: marksMutation)
        case .mention(let mention, var marks):
            return mutateMentionContent(mention, marks: &marks, marksMutation: marksMutation)
        case .status(let status, var marks):
            return mutateStatusContent(status, marks: &marks, marksMutation: marksMutation)
        case .mathInline(let math, var marks):
            return mutateMathInlineContent(math, marks: &marks, marksMutation: marksMutation)
        case .unsupported(var node):
            guard unsupportedNodeMutation(&node) else { return (content, false) }
            return (.unsupported(node), true)
        case .hardBreak:
            return (content, false)
        }
    }

    private static func mutateTextContent(
        _ text: String,
        marks: inout [NativeEditorTextMark],
        marksMutation: (inout [NativeEditorTextMark]) -> Bool
    ) -> (NativeEditorInlineContent, Bool) {
        guard marksMutation(&marks) else { return (.text(text, marks: marks), false) }
        return (.text(text, marks: marks), true)
    }

    private static func mutateMentionContent(
        _ mention: NativeEditorMention,
        marks: inout [NativeEditorTextMark],
        marksMutation: (inout [NativeEditorTextMark]) -> Bool
    ) -> (NativeEditorInlineContent, Bool) {
        guard marksMutation(&marks) else { return (.mention(mention, marks: marks), false) }
        return (.mention(mention, marks: marks), true)
    }

    private static func mutateStatusContent(
        _ status: NativeEditorStatusBadge,
        marks: inout [NativeEditorTextMark],
        marksMutation: (inout [NativeEditorTextMark]) -> Bool
    ) -> (NativeEditorInlineContent, Bool) {
        guard marksMutation(&marks) else { return (.status(status, marks: marks), false) }
        return (.status(status, marks: marks), true)
    }

    private static func mutateMathInlineContent(
        _ math: NativeEditorMathInline,
        marks: inout [NativeEditorTextMark],
        marksMutation: (inout [NativeEditorTextMark]) -> Bool
    ) -> (NativeEditorInlineContent, Bool) {
        guard marksMutation(&marks) else { return (.mathInline(math, marks: marks), false) }
        return (.mathInline(math, marks: marks), true)
    }

    private static func updateInlineCommentResolved(
        commentID: String,
        isResolved: Bool,
        in marks: inout [NativeEditorTextMark]
    ) -> Bool {
        var didUpdate = false
        for index in marks.indices where marks[index].commentID == commentID {
            marks[index] = .comment(commentID: commentID, isResolved: isResolved)
            didUpdate = true
        }
        return didUpdate
    }

    private static func removeInlineComment(
        commentID: String,
        from marks: inout [NativeEditorTextMark]
    ) -> Bool {
        let originalCount = marks.count
        marks.removeAll { $0.commentID == commentID }
        return marks.count != originalCount
    }

    private static func updateInlineCommentResolved(
        commentID: String,
        isResolved: Bool,
        in node: inout ProseMirrorNode?
    ) -> Bool {
        guard var updatedNode = node else { return false }
        guard updateInlineCommentResolved(commentID: commentID, isResolved: isResolved, in: &updatedNode) else {
            return false
        }

        node = updatedNode
        return true
    }

    private static func updateInlineCommentResolved(
        commentID: String,
        isResolved: Bool,
        in nodes: inout [ProseMirrorNode]?
    ) -> Bool {
        guard var updatedNodes = nodes else { return false }
        guard updateInlineCommentResolved(commentID: commentID, isResolved: isResolved, in: &updatedNodes) else {
            return false
        }

        nodes = updatedNodes
        return true
    }

    private static func updateInlineCommentResolved(
        commentID: String,
        isResolved: Bool,
        in nodes: inout [ProseMirrorNode]
    ) -> Bool {
        var didUpdate = false
        for index in nodes.indices where updateInlineCommentResolved(
            commentID: commentID,
            isResolved: isResolved,
            in: &nodes[index]
        ) {
            didUpdate = true
        }
        return didUpdate
    }

    private static func updateInlineCommentResolved(
        commentID: String,
        isResolved: Bool,
        in node: inout ProseMirrorNode
    ) -> Bool {
        let didUpdateMarks = updateInlineCommentResolved(commentID: commentID, isResolved: isResolved, in: &node.marks)
        let didUpdateContent = updateInlineCommentResolved(
            commentID: commentID,
            isResolved: isResolved,
            in: &node.content
        )
        return didUpdateMarks || didUpdateContent
    }

    private static func updateInlineCommentResolved(
        commentID: String,
        isResolved: Bool,
        in marks: inout [ProseMirrorMark]?
    ) -> Bool {
        guard var updatedMarks = marks else { return false }
        guard updateInlineCommentResolved(commentID: commentID, isResolved: isResolved, in: &updatedMarks) else {
            return false
        }

        marks = updatedMarks
        return true
    }

    private static func updateInlineCommentResolved(
        commentID: String,
        isResolved: Bool,
        in marks: inout [ProseMirrorMark]
    ) -> Bool {
        var didUpdate = false
        for index in marks.indices where marks[index].commentID == commentID {
            var attrs = marks[index].attrs ?? [:]
            attrs["resolved"] = .bool(isResolved)
            marks[index].attrs = attrs
            didUpdate = true
        }
        return didUpdate
    }

    private static func removeInlineComment(
        commentID: String,
        from node: inout ProseMirrorNode?
    ) -> Bool {
        guard var updatedNode = node else { return false }
        guard removeInlineComment(commentID: commentID, from: &updatedNode) else { return false }

        node = updatedNode
        return true
    }

    private static func removeInlineComment(
        commentID: String,
        from nodes: inout [ProseMirrorNode]?
    ) -> Bool {
        guard var updatedNodes = nodes else { return false }
        guard removeInlineComment(commentID: commentID, from: &updatedNodes) else { return false }

        nodes = updatedNodes
        return true
    }

    private static func removeInlineComment(
        commentID: String,
        from nodes: inout [ProseMirrorNode]
    ) -> Bool {
        var didUpdate = false
        for index in nodes.indices where removeInlineComment(commentID: commentID, from: &nodes[index]) {
            didUpdate = true
        }
        return didUpdate
    }

    private static func removeInlineComment(
        commentID: String,
        from node: inout ProseMirrorNode
    ) -> Bool {
        let didUpdateMarks = removeInlineComment(commentID: commentID, from: &node.marks)
        let didUpdateContent = removeInlineComment(commentID: commentID, from: &node.content)
        return didUpdateMarks || didUpdateContent
    }

    private static func removeInlineComment(
        commentID: String,
        from marks: inout [ProseMirrorMark]?
    ) -> Bool {
        guard var updatedMarks = marks else { return false }
        guard removeInlineComment(commentID: commentID, from: &updatedMarks) else { return false }

        marks = updatedMarks.isEmpty ? nil : updatedMarks
        return true
    }

    private static func removeInlineComment(
        commentID: String,
        from marks: inout [ProseMirrorMark]
    ) -> Bool {
        let originalCount = marks.count
        marks.removeAll { $0.commentID == commentID }
        return marks.count != originalCount
    }
}

private extension AttributedString {
    mutating func setNativeEditorInlineComments(
        _ comments: [NativeEditorInlineCommentMark],
        in range: Range<AttributedString.Index>,
        fallbackBackgroundColor: Color? = nil
    ) {
        let normalizedComments = comments.normalizedNativeEditorInlineComments
        self[range][NativeEditorCommentMarksAttribute.self] = normalizedComments.isEmpty ? nil : normalizedComments
        self[range][NativeEditorCommentIDAttribute.self] = normalizedComments.first?.commentID
        self[range][NativeEditorCommentResolvedAttribute.self] = normalizedComments.first?.isResolved
        self[range].backgroundColor = backgroundColor(
            for: normalizedComments,
            fallbackBackgroundColor: fallbackBackgroundColor
        )
    }

    private func backgroundColor(
        for comments: [NativeEditorInlineCommentMark],
        fallbackBackgroundColor: Color?
    ) -> Color? {
        guard comments.isEmpty == false else { return fallbackBackgroundColor }
        return comments.contains { $0.isResolved == false }
            ? .yellow.opacity(0.28)
            : .gray.opacity(0.16)
    }
}

private extension NativeEditorTextMark {
    var commentID: String? {
        guard case .comment(let commentID, _) = self else { return nil }
        return commentID
    }
}

private extension ProseMirrorMark {
    var commentID: String? {
        guard type == "comment" else { return nil }
        return attrs?["commentId"]?.stringValue
    }
}
