import Foundation

nonisolated extension NativeEditorDocument {
    static func blockquoteNode(from block: NativeEditorBlock) -> ProseMirrorNode {
        let textNode = blockquoteTextContainerNode(from: block)
        guard block.rawNode?.type == "blockquote" else {
            return ProseMirrorNode(type: "blockquote", content: [textNode])
        }

        var content = block.rawNode?.content ?? []
        if let textIndex = content.firstIndex(where: isBlockquoteTextContainer) {
            content[textIndex] = textNode
        } else {
            content.insert(textNode, at: content.startIndex)
        }

        let attrs = block.rawNode?.attrs ?? [:]
        return ProseMirrorNode(
            type: "blockquote",
            attrs: attrs.isEmpty ? nil : attrs,
            content: content
        )
    }

    private static func blockquoteTextContainerNode(from block: NativeEditorBlock) -> ProseMirrorNode {
        guard block.rawNode?.type == "blockquote" else {
            return textContainerNode(type: "paragraph", block: block)
        }

        let originalNode = block.rawNode?.content?.first(where: isBlockquoteTextContainer)
        let nodeType = originalNode?.type ?? "paragraph"
        var attrs = originalNode?.attrs ?? [:]

        if let alignment = block.alignment.proseMirrorValue {
            attrs["textAlign"] = alignment
        } else {
            attrs.removeValue(forKey: "textAlign")
        }

        return ProseMirrorNode(
            type: nodeType,
            attrs: attrs.isEmpty ? nil : attrs,
            content: blockquoteTextContainerContent(type: nodeType, block: block)
        )
    }

    private static func blockquoteTextContainerContent(
        type: String,
        block: NativeEditorBlock
    ) -> [ProseMirrorNode] {
        if type == "codeBlock" {
            let text = String(block.text.characters)
            return text.isEmpty ? [] : [ProseMirrorNode(type: "text", text: text)]
        }

        return block.inlineContent.map(inlineNodes(from:)) ?? inlineNodes(from: block.text)
    }

    private static func isBlockquoteTextContainer(_ node: ProseMirrorNode) -> Bool {
        node.type == "paragraph" || node.type == "heading" || node.type == "codeBlock"
    }
}
