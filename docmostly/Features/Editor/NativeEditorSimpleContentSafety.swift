import Foundation

nonisolated enum NativeEditorSimpleContentSafety {
    private static let supportedParagraphAttributeNames: Set<String> = ["id", "indent", "textAlign"]

    static func plainBlockText(in nodes: [ProseMirrorNode]) -> String? {
        guard nodes.isEmpty == false else { return "" }
        guard nodes.count == 1, let paragraph = nodes.first else { return nil }
        guard paragraph.type == "paragraph", hasSafeParagraphMetadata(paragraph) else { return nil }
        guard paragraph.text == nil else { return nil }
        return plainInlineText(in: paragraph.content ?? [])
    }

    static func plainInlineText(in nodes: [ProseMirrorNode]) -> String? {
        var text = ""

        for node in nodes {
            guard hasNoSemanticMetadata(node), node.content?.isEmpty != false else { return nil }

            switch node.type {
            case "text":
                text += node.text ?? ""
            case "hardBreak":
                guard node.text == nil else { return nil }
                text += "\n"
            default:
                return nil
            }
        }

        return text
    }

    private static func hasNoSemanticMetadata(_ node: ProseMirrorNode) -> Bool {
        (node.attrs?.isEmpty ?? true) && (node.marks?.isEmpty ?? true)
    }

    private static func hasSafeParagraphMetadata(_ node: ProseMirrorNode) -> Bool {
        let hasOnlySupportedAttributes = node.attrs?.keys.allSatisfy { attributeName in
            supportedParagraphAttributeNames.contains(attributeName)
        } ?? true
        return hasOnlySupportedAttributes && (node.marks?.isEmpty ?? true)
    }
}
