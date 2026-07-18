import Foundation

extension NativeRichEditorViewModel {
    func setColumnCount(blockID: UUID, count: Int) {
        updateRichBlock(blockID: blockID) { block in
            guard var node = block.rawNode, node.type == "columns" else { return }
            let normalizedCount = min(max(count, 2), NativeEditorColumnsBlock.maximumColumnCount)
            var columns = (node.content ?? []).filter { $0.type == "column" }
            guard columns.count != normalizedCount else { return }

            if columns.count < normalizedCount {
                columns.append(contentsOf: (columns.count..<normalizedCount).map { _ in
                    Self.nestedColumnNode(text: "", width: nil)
                })
            } else {
                columns = Self.mergingRemovedColumns(columns, retainedCount: normalizedCount)
            }

            var attrs = node.attrs ?? [:]
            attrs["layout"] = .string(Self.defaultColumnsLayout(for: normalizedCount))
            node.attrs = attrs
            node.content = columns
            Self.refreshNestedBlock(&block, from: node)
        }
    }

    func updateColumnWidth(blockID: UUID, columnIndex: Int, width: Double?) {
        updateRichBlock(blockID: blockID) { block in
            guard var node = block.rawNode, node.type == "columns" else { return }
            let columnNodeIndices = (node.content ?? []).indices.filter {
                node.content?[$0].type == "column"
            }
            guard columnNodeIndices.indices.contains(columnIndex), var content = node.content else { return }

            let nodeIndex = columnNodeIndices[columnIndex]
            var attrs = content[nodeIndex].attrs ?? [:]
            if let width, width.isFinite, width > 0 {
                attrs["width"] = .double(min(max(width, 0.25), 4))
            } else {
                attrs.removeValue(forKey: "width")
            }
            content[nodeIndex].attrs = attrs.isEmpty ? nil : attrs
            node.content = content
            Self.refreshNestedBlock(&block, from: node)
        }
    }

    func updateNestedContent(
        blockID: UUID,
        target: NativeEditorNestedContentTarget,
        content: [ProseMirrorNode]
    ) {
        updateRichBlock(blockID: blockID) { block in
            guard let node = Self.updatedNestedNode(block.rawNode, target: target, content: content) else {
                return
            }
            Self.refreshNestedBlock(&block, from: node)
        }
    }

    private static func updatedNestedNode(
        _ existingNode: ProseMirrorNode?,
        target: NativeEditorNestedContentTarget,
        content: [ProseMirrorNode]
    ) -> ProseMirrorNode? {
        switch target {
        case .callout:
            updatedCallout(existingNode, content: content)
        case .detailsContent:
            updatedDetails(existingNode, content: content)
        case .column(let columnIndex):
            updatedColumns(existingNode, columnIndex: columnIndex, content: content)
        case .transclusionSource:
            updatedTransclusionSource(existingNode, content: content)
        }
    }

    private static func updatedCallout(
        _ existingNode: ProseMirrorNode?,
        content: [ProseMirrorNode]
    ) -> ProseMirrorNode? {
        guard var node = existingNode, node.type == "callout" else { return nil }
        node.content = nonEmptyBlockContent(content)
        return node
    }

    private static func updatedDetails(
        _ existingNode: ProseMirrorNode?,
        content: [ProseMirrorNode]
    ) -> ProseMirrorNode? {
        guard var node = existingNode, node.type == "details" else { return nil }
        var children = node.content ?? []
        if let index = children.firstIndex(where: { $0.type == "detailsContent" }) {
            children[index].content = content
        } else {
            children.append(ProseMirrorNode(type: "detailsContent", content: content))
        }
        node.content = children
        return node
    }

    private static func updatedColumns(
        _ existingNode: ProseMirrorNode?,
        columnIndex: Int,
        content: [ProseMirrorNode]
    ) -> ProseMirrorNode? {
        guard var node = existingNode, node.type == "columns", var children = node.content else { return nil }
        let indices = children.indices.filter { children[$0].type == "column" }
        guard indices.indices.contains(columnIndex) else { return nil }
        children[indices[columnIndex]].content = nonEmptyBlockContent(content)
        node.content = children
        return node
    }

    private static func updatedTransclusionSource(
        _ existingNode: ProseMirrorNode?,
        content: [ProseMirrorNode]
    ) -> ProseMirrorNode? {
        guard var node = existingNode,
              node.type == "transclusionSource",
              content.allSatisfy({ transclusionSourceAllowedNodeTypes.contains($0.type) })
        else {
            return nil
        }
        node.content = nonEmptyBlockContent(content)
        return node
    }

    private static func mergingRemovedColumns(
        _ columns: [ProseMirrorNode],
        retainedCount: Int
    ) -> [ProseMirrorNode] {
        var retainedColumns = Array(columns.prefix(retainedCount))
        let removedContent = columns.dropFirst(retainedCount).flatMap { column in
            (column.content ?? []).filter(isNonEmptyColumnChild)
        }
        if removedContent.isEmpty == false {
            retainedColumns[retainedCount - 1].content =
                (retainedColumns[retainedCount - 1].content ?? []) + removedContent
        }
        return retainedColumns
    }

    private static let transclusionSourceAllowedNodeTypes: Set<String> = [
        "paragraph", "heading", "blockquote", "codeBlock", "horizontalRule", "bulletList", "orderedList",
        "taskList", "image", "video", "audio", "attachment", "callout", "details", "embed", "mathBlock",
        "table", "drawio", "excalidraw", "pdf", "subpages", "columns", "youtube"
    ]

    private static func nonEmptyBlockContent(_ content: [ProseMirrorNode]) -> [ProseMirrorNode] {
        content.isEmpty ? [nestedParagraphNode("")] : content
    }

    private static func isNonEmptyColumnChild(_ node: ProseMirrorNode) -> Bool {
        node.type != "paragraph" || (node.content?.isEmpty == false)
    }

    private static func defaultColumnsLayout(for count: Int) -> String {
        switch count {
        case 3: "three_equal"
        case 4: "four_equal"
        case 5: "five_equal"
        default: "two_equal"
        }
    }

    private static func refreshNestedBlock(_ block: inout NativeEditorBlock, from node: ProseMirrorNode) {
        switch node.type {
        case "callout":
            let callout = NativeEditorDocument.calloutBlock(from: node)
            block.kind = .callout(callout)
            block.text = AttributedString(callout.previewText)
        case "details":
            let details = NativeEditorDocument.detailsBlock(from: node)
            block.kind = .details(details)
            block.text = AttributedString(details.summary)
        case "columns":
            let columns = NativeEditorDocument.columnsBlock(from: node)
            block.kind = .columns(columns)
            block.text = AttributedString(columns.previewText)
        case "transclusionSource":
            let source = NativeEditorDocument.transclusionSourceBlock(from: node)
            block.kind = .transclusionSource(source)
            block.text = AttributedString(source.previewText)
        default:
            return
        }
        block.rawNode = node
    }

    private static func nestedParagraphNode(_ text: String) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "paragraph",
            content: NativeEditorDocument.inlineNodes(from: AttributedString(text))
        )
    }

    private static func nestedColumnNode(text: String, width: Double?) -> ProseMirrorNode {
        ProseMirrorNode(
            type: "column",
            attrs: ["width": width.map(ProseMirrorJSONValue.double) ?? .null],
            content: [nestedParagraphNode(text)]
        )
    }
}
