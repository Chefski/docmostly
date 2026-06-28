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
            transclusionSourceHTMLMarkdown(from: source)
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
        var bodyLines: [String] = []
        var currentIndex = lines.index(after: index)

        while currentIndex < lines.endIndex {
            let line = lines[currentIndex]
            if containsHTMLClosingTag(in: line, tagName: "div") {
                let source = NativeEditorTransclusionSourceBlock(
                    identifier: nonEmptyStructuralHTMLAttribute(attributes["data-id"]),
                    previewText: structuralHTMLText(from: bodyLines)
                )
                return (
                    docmostStructuralBlock(
                        kind: .transclusionSource(source),
                        rawNode: NativeEditorRichBlockNodeFactory.transclusionSourceNode(from: source)
                    ),
                    lines.index(after: currentIndex)
                )
            }

            bodyLines.append(line)
            currentIndex = lines.index(after: currentIndex)
        }

        return nil
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
