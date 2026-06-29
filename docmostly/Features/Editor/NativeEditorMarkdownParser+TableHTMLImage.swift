import Foundation

extension NativeEditorMarkdownParser {
    static func htmlTableImageContentMatches(
        from html: String,
        excluding excludedRanges: [NSRange]
    ) -> [HTMLTableContentMatch] {
        htmlRegexMatches(pattern: #"<img\b([^>]*)/?>"#, in: html)
            .compactMap { match -> HTMLTableContentMatch? in
                guard htmlTableRange(match.range, isNestedIn: excludedRanges) == false,
                      let attributeText = htmlRegexString(match: match, captureIndex: 1, in: html) else {
                    return nil
                }

                return HTMLTableContentMatch(
                    range: match.range,
                    node: htmlTableImageNode(attrs: docmostInlineHTMLAttributes(from: "<img\(attributeText)>"))
                )
            }
    }

    private static func htmlTableImageNode(attrs: [String: String]) -> ProseMirrorNode {
        var nodeAttrs = [String: ProseMirrorJSONValue]()
        let source = nonEmptyHTMLTableAttribute(attrs["src"])

        if let source {
            nodeAttrs["src"] = .string(source)
        }
        if let alternativeText = nonEmptyHTMLTableAttribute(attrs["alt"]) {
            nodeAttrs["alt"] = .string(alternativeText)
        }
        if let title = nonEmptyHTMLTableAttribute(attrs["title"]) {
            nodeAttrs["title"] = .string(title)
        }
        if let attachmentID = nonEmptyHTMLTableAttribute(attrs["data-attachment-id"]) ??
            source.flatMap(docmostAttachmentID) {
            nodeAttrs["attachmentId"] = .string(attachmentID)
        }
        if let sizeInBytes = nonEmptyHTMLTableAttribute(attrs["data-size"]).flatMap(Int.init) {
            nodeAttrs["size"] = .int(sizeInBytes)
        }
        if let width = nonEmptyHTMLTableAttribute(attrs["width"]).flatMap(htmlTableProseMirrorNumberOrString) {
            nodeAttrs["width"] = width
        }
        if let height = nonEmptyHTMLTableAttribute(attrs["height"]).flatMap(htmlTableProseMirrorNumberOrString) {
            nodeAttrs["height"] = height
        }
        if let aspectRatio = nonEmptyHTMLTableAttribute(attrs["data-aspect-ratio"]).flatMap(Double.init) {
            nodeAttrs["aspectRatio"] = .double(aspectRatio)
        }
        if let alignment = nonEmptyHTMLTableAttribute(attrs["data-align"]) {
            nodeAttrs["align"] = .string(alignment)
        }

        return ProseMirrorNode(type: "image", attrs: nodeAttrs.isEmpty ? nil : nodeAttrs)
    }

    private static func htmlTableProseMirrorNumberOrString(from value: String) -> ProseMirrorJSONValue? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedValue.isEmpty == false else { return nil }
        if let intValue = Int(trimmedValue) {
            return .int(intValue)
        }
        if let doubleValue = Double(trimmedValue) {
            return .double(doubleValue)
        }
        return .string(trimmedValue)
    }
}
