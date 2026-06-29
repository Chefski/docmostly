import Foundation

extension NativeEditorMarkdownParser {
    static func docmostStructuralHTMLBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        guard let attributes = docmostStructuralHTMLAttributes(from: lines[index]) else {
            return nil
        }

        switch attributes["data-type"] {
        case "subpages":
            return (
                docmostStructuralBlock(kind: .subpages, rawNode: ProseMirrorNode(type: "subpages")),
                lines.index(after: index)
            )
        case "transclusionSource":
            return transclusionSourceHTMLBlock(in: lines, startingAt: index, attributes: attributes)
        case "transclusionReference":
            let reference = NativeEditorTransclusionReferenceBlock(
                sourcePageID: nonEmptyStructuralHTMLAttribute(attributes["data-source-page-id"]),
                transclusionID: nonEmptyStructuralHTMLAttribute(attributes["data-transclusion-id"])
            )
            return (
                docmostStructuralBlock(
                    kind: .transclusionReference(reference),
                    rawNode: NativeEditorRichBlockNodeFactory.transclusionReferenceNode(from: reference)
                ),
                lines.index(after: index)
            )
        case "base-embed":
            let base = NativeEditorBaseBlock(
                pageID: nonEmptyStructuralHTMLAttribute(attributes["data-page-id"]),
                pendingKey: nil,
                previewText: "Base"
            )
            return (
                docmostStructuralBlock(
                    kind: .base(base),
                    rawNode: NativeEditorRichBlockNodeFactory.baseNode(from: base)
                ),
                lines.index(after: index)
            )
        default:
            return nil
        }
    }

    static func docmostStructuralHTMLMarkdown(from block: NativeEditorBlock) -> String? {
        switch block.kind {
        case .subpages:
            #"<div data-type="subpages"></div>"#
        case .transclusionSource(let source):
            rawTransclusionSourceHTMLMarkdown(from: block.rawNode) ?? transclusionSourceHTMLMarkdown(from: source)
        case .transclusionReference(let reference):
            transclusionReferenceHTMLMarkdown(from: reference)
        case .base(let base):
            baseHTMLMarkdown(from: base)
        default:
            nil
        }
    }

    private static func transclusionSourceHTMLBlock(
        in lines: [String],
        startingAt index: Array<String>.Index,
        attributes: [String: String]
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        guard let body = htmlContainerBody(in: lines, startingAt: index, tagName: "div") else {
            return nil
        }

        let contentNodes = containerContentNodes(from: body.lines)
        let source = NativeEditorTransclusionSourceBlock(
            identifier: nonEmptyStructuralHTMLAttribute(attributes["data-id"]),
            previewText: containerPreviewText(from: contentNodes)
        )
        return (
            docmostStructuralBlock(
                kind: .transclusionSource(source),
                rawNode: transclusionSourceHTMLNode(from: source, content: contentNodes)
            ),
            body.endIndex
        )
    }

    private static func transclusionSourceHTMLMarkdown(from source: NativeEditorTransclusionSourceBlock) -> String {
        let openingTag = structuralHTMLTag("div", attributes: [
            ("data-type", "transclusionSource"),
            ("data-id", source.identifier)
        ])
        let previewText = escapedInlineHTMLText(source.previewText.trimmingCharacters(in: .whitespacesAndNewlines))

        return """
        \(openingTag)
        \(previewText)
        </div>
        """
    }

    private static func rawTransclusionSourceHTMLMarkdown(from node: ProseMirrorNode?) -> String? {
        guard
            let node,
            node.type == "transclusionSource",
            rawTransclusionSourceNeedsStructuredMarkdown(node)
        else {
            return nil
        }

        let openingTag = structuralHTMLTag("div", attributes: [
            ("data-type", "transclusionSource"),
            ("data-id", node.attrs?["id"]?.stringValue)
        ])
        let body = (node.content ?? [])
            .map(structuralContentHTMLMarkdown(from:))
            .joined(separator: "\n")

        return """
        \(openingTag)
        \(body)
        </div>
        """
    }

    private static func rawTransclusionSourceNeedsStructuredMarkdown(_ node: ProseMirrorNode) -> Bool {
        let content = node.content ?? []
        guard content.count == 1, content.first?.type == "paragraph" else {
            return content.isEmpty == false
        }

        return false
    }

    private static func transclusionSourceHTMLNode(
        from source: NativeEditorTransclusionSourceBlock,
        content: [ProseMirrorNode]
    ) -> ProseMirrorNode {
        var attrs = [String: ProseMirrorJSONValue]()
        if let identifier = source.identifier, identifier.isEmpty == false {
            attrs["id"] = .string(identifier)
        }

        return ProseMirrorNode(
            type: "transclusionSource",
            attrs: attrs.isEmpty ? nil : attrs,
            content: content.isEmpty ? [
                ProseMirrorNode(
                    type: "paragraph",
                    content: NativeEditorDocument.inlineNodes(from: inlineText(from: source.previewText))
                )
            ] : content
        )
    }

    private static func transclusionReferenceHTMLMarkdown(
        from reference: NativeEditorTransclusionReferenceBlock
    ) -> String {
        let openingTag = structuralHTMLTag("div", attributes: [
            ("data-type", "transclusionReference"),
            ("data-source-page-id", reference.sourcePageID),
            ("data-transclusion-id", reference.transclusionID)
        ])
        return "\(openingTag)</div>"
    }

    private static func baseHTMLMarkdown(from base: NativeEditorBaseBlock) -> String {
        let openingTag = structuralHTMLTag("div", attributes: [
            ("data-type", "base-embed"),
            ("data-page-id", base.pageID)
        ])
        return "\(openingTag)</div>"
    }

    private static func docmostStructuralBlock(
        kind: NativeEditorBlockKind,
        rawNode: ProseMirrorNode
    ) -> NativeEditorBlock {
        NativeEditorBlock(
            kind: kind,
            text: AttributedString(NativeEditorDocument.previewText(for: kind)),
            alignment: .left,
            rawNode: rawNode
        )
    }

    private static func docmostStructuralHTMLAttributes(from line: String) -> [String: String]? {
        guard let attributes = htmlTagAttributes(from: line, tagName: "div") else {
            return nil
        }

        guard let dataType = attributes["data-type"],
              docmostStructuralHTMLTypes.contains(dataType) else {
            return nil
        }

        return attributes
    }

    private static func structuralHTMLText(from lines: [String]) -> String {
        lines.map(unescapedInlineHTMLText)
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func structuralContentHTMLMarkdown(from node: ProseMirrorNode) -> String {
        switch node.type {
        case "paragraph":
            "<p>\(structuralInlineHTMLMarkdown(from: node.content ?? []))</p>"
        case "heading":
            structuralHeadingHTMLMarkdown(from: node)
        case "pageBreak":
            #"<div data-type="pageBreak" class="page-break"></div>"#
        case "horizontalRule":
            "<hr>"
        case "codeBlock":
            structuralCodeBlockHTMLMarkdown(from: node)
        default:
            escapedInlineHTMLText(NativeEditorDocument.plainText(in: [node]))
        }
    }

    private static func structuralHeadingHTMLMarkdown(from node: ProseMirrorNode) -> String {
        let level = min(max(node.attrs?["level"]?.intValue ?? 1, 1), 6)
        return "<h\(level)>\(structuralInlineHTMLMarkdown(from: node.content ?? []))</h\(level)>"
    }

    private static func structuralCodeBlockHTMLMarkdown(from node: ProseMirrorNode) -> String {
        let language = node.attrs?["language"]?.stringValue
            .map { #" class="language-\#(escapedInlineHTMLAttribute($0))""# } ?? ""
        return "<pre><code\(language)>\(escapedInlineHTMLText(NativeEditorDocument.plainText(in: [node])))</code></pre>"
    }

    private static func structuralInlineHTMLMarkdown(from nodes: [ProseMirrorNode]) -> String {
        nodes.map { node in
            switch node.type {
            case "text":
                escapedInlineHTMLText(node.text ?? "")
            case "hardBreak":
                "<br>"
            default:
                escapedInlineHTMLText(NativeEditorDocument.plainText(in: [node]))
            }
        }
        .joined()
    }

    private static func structuralHTMLTag(_ name: String, attributes: [(String, String?)]) -> String {
        let attributeText = attributes.compactMap { key, value -> String? in
            guard let value = nonEmptyStructuralHTMLAttribute(value) else { return nil }
            return #"\#(key)="\#(escapedInlineHTMLAttribute(value))""#
        }.joined(separator: " ")

        return attributeText.isEmpty ? "<\(name)>" : "<\(name) \(attributeText)>"
    }

    private static func nonEmptyStructuralHTMLAttribute(_ value: String?) -> String? {
        guard let value, value.isEmpty == false else {
            return nil
        }
        return value
    }

    private static var docmostStructuralHTMLTypes: Set<String> {
        ["base-embed", "subpages", "transclusionReference", "transclusionSource"]
    }
}
