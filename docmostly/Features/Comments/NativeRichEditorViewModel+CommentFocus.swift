import Foundation

extension NativeRichEditorViewModel {
    func blockID(containingInlineComment commentID: String) -> UUID? {
        document.blocks.first { block in
            block.text.runs.contains { $0.hasNativeEditorInlineComment(commentID: commentID) }
                || block.rawNode.map { Self.containsInlineComment(commentID, in: $0) } == true
        }?.id
    }

    private static func containsInlineComment(_ commentID: String, in rootNode: ProseMirrorNode) -> Bool {
        var pendingNodes = [rootNode]
        while let node = pendingNodes.popLast() {
            if (node.marks ?? []).contains(where: { mark in
                mark.type == "comment" && mark.attrs?["commentId"]?.stringValue == commentID
            }) {
                return true
            }
            pendingNodes.append(contentsOf: node.content ?? [])
        }
        return false
    }
}
