import Foundation

extension NativeEditorMarkdownParser {
    static func htmlTableMediaContentMatches(
        from html: String,
        excluding excludedRanges: [NSRange]
    ) -> [HTMLTableContentMatch] {
        htmlTableImageContentMatches(from: html, excluding: excludedRanges) +
            htmlTableMediaElementContentMatches(from: html, excluding: excludedRanges, type: "video") +
            htmlTableMediaElementContentMatches(from: html, excluding: excludedRanges, type: "audio") +
            htmlTableTypedMediaDivContentMatches(from: html, excluding: excludedRanges)
    }

    private static func htmlTableImageContentMatches(
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

    private static func htmlTableMediaElementContentMatches(
        from html: String,
        excluding excludedRanges: [NSRange],
        type: String
    ) -> [HTMLTableContentMatch] {
        htmlRegexMatches(pattern: #"<\#(type)\b([^>]*)>(.*?)</\#(type)>"#, in: html)
            .compactMap { match -> HTMLTableContentMatch? in
                guard htmlTableRange(match.range, isNestedIn: excludedRanges) == false,
                      let attributeText = htmlRegexString(match: match, captureIndex: 1, in: html),
                      let body = htmlRegexString(match: match, captureIndex: 2, in: html) else {
                    return nil
                }

                let attrs = docmostInlineHTMLAttributes(from: "<\(type)\(attributeText)>")
                let sourceAttrs = firstHTMLTagAttributes(in: body, tagName: "source") ?? [:]
                return HTMLTableContentMatch(
                    range: match.range,
                    node: htmlTableMediaElementNode(type: type, attrs: attrs, sourceAttrs: sourceAttrs)
                )
            }
    }

    private static func htmlTableTypedMediaDivContentMatches(
        from html: String,
        excluding excludedRanges: [NSRange]
    ) -> [HTMLTableContentMatch] {
        htmlRegexMatches(pattern: #"<div\b([^>]*)>(.*?)</div>"#, in: html)
            .compactMap { match -> HTMLTableContentMatch? in
                guard htmlTableRange(match.range, isNestedIn: excludedRanges) == false,
                      let attributeText = htmlRegexString(match: match, captureIndex: 1, in: html),
                      let body = htmlRegexString(match: match, captureIndex: 2, in: html) else {
                    return nil
                }

                let attrs = docmostInlineHTMLAttributes(from: "<div\(attributeText)>")
                guard let type = htmlTableTypedMediaDivType(from: attrs["data-type"]) else { return nil }

                return HTMLTableContentMatch(
                    range: match.range,
                    node: htmlTableTypedMediaDivNode(type: type, attrs: attrs, body: body)
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

    private static func htmlTableMediaElementNode(
        type: String,
        attrs: [String: String],
        sourceAttrs: [String: String]
    ) -> ProseMirrorNode {
        var nodeAttrs = [String: ProseMirrorJSONValue]()
        let source = nonEmptyHTMLTableAttribute(attrs["src"]) ?? nonEmptyHTMLTableAttribute(sourceAttrs["src"])

        if let source {
            nodeAttrs["src"] = .string(source)
        }
        if type == "video",
           let alternativeText = nonEmptyHTMLTableAttribute(attrs["aria-label"]) ??
            nonEmptyHTMLTableAttribute(attrs["alt"]) {
            nodeAttrs["alt"] = .string(alternativeText)
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

        return ProseMirrorNode(type: type, attrs: nodeAttrs.isEmpty ? nil : nodeAttrs)
    }

    private static func htmlTableTypedMediaDivNode(
        type: String,
        attrs: [String: String],
        body: String
    ) -> ProseMirrorNode {
        if type == "pdf" {
            let iframeAttrs = firstHTMLTagAttributes(in: body, tagName: "iframe") ?? [:]
            return htmlTablePDFNode(attrs: attrs, iframeAttrs: iframeAttrs)
        }

        let linkAttrs = firstHTMLTagAttributes(in: body, tagName: "a") ?? [:]
        return htmlTableAttachmentNode(attrs: attrs, linkAttrs: linkAttrs)
    }

    private static func htmlTablePDFNode(
        attrs: [String: String],
        iframeAttrs: [String: String]
    ) -> ProseMirrorNode {
        var nodeAttrs = [String: ProseMirrorJSONValue]()
        let source = nonEmptyHTMLTableAttribute(attrs["src"]) ?? nonEmptyHTMLTableAttribute(iframeAttrs["src"])

        if let source {
            nodeAttrs["src"] = .string(source)
        }
        if let name = nonEmptyHTMLTableAttribute(attrs["data-name"]) {
            nodeAttrs["name"] = .string(name)
        }
        if let attachmentID = nonEmptyHTMLTableAttribute(attrs["data-attachment-id"]) ??
            source.flatMap(docmostAttachmentID) {
            nodeAttrs["attachmentId"] = .string(attachmentID)
        }
        if let sizeInBytes = nonEmptyHTMLTableAttribute(attrs["data-size"]).flatMap(Int.init) {
            nodeAttrs["size"] = .int(sizeInBytes)
        }
        let widthValue = nonEmptyHTMLTableAttribute(attrs["width"]) ?? nonEmptyHTMLTableAttribute(iframeAttrs["width"])
        let heightValue = nonEmptyHTMLTableAttribute(attrs["height"]) ??
            nonEmptyHTMLTableAttribute(iframeAttrs["height"])
        if let width = widthValue.flatMap(htmlTableProseMirrorNumberOrString) {
            nodeAttrs["width"] = width
        }
        if let height = heightValue.flatMap(htmlTableProseMirrorNumberOrString) {
            nodeAttrs["height"] = height
        }

        return ProseMirrorNode(type: "pdf", attrs: nodeAttrs.isEmpty ? nil : nodeAttrs)
    }

    private static func htmlTableAttachmentNode(
        attrs: [String: String],
        linkAttrs: [String: String]
    ) -> ProseMirrorNode {
        var nodeAttrs = [String: ProseMirrorJSONValue]()
        let source = nonEmptyHTMLTableAttribute(attrs["data-attachment-url"]) ??
            nonEmptyHTMLTableAttribute(linkAttrs["href"])

        if let source {
            nodeAttrs["url"] = .string(source)
        }
        if let name = nonEmptyHTMLTableAttribute(attrs["data-attachment-name"]) {
            nodeAttrs["name"] = .string(name)
        }
        if let mimeType = nonEmptyHTMLTableAttribute(attrs["data-attachment-mime"]) {
            nodeAttrs["mime"] = .string(mimeType)
        }
        if let sizeInBytes = nonEmptyHTMLTableAttribute(attrs["data-attachment-size"]).flatMap(Int.init) {
            nodeAttrs["size"] = .int(sizeInBytes)
        }
        if let attachmentID = nonEmptyHTMLTableAttribute(attrs["data-attachment-id"]) ??
            source.flatMap(docmostAttachmentID) {
            nodeAttrs["attachmentId"] = .string(attachmentID)
        }

        return ProseMirrorNode(type: "attachment", attrs: nodeAttrs.isEmpty ? nil : nodeAttrs)
    }

    private static func htmlTableTypedMediaDivType(from dataType: String?) -> String? {
        guard let dataType else { return nil }
        if dataType.localizedCaseInsensitiveCompare("pdf") == .orderedSame {
            return "pdf"
        }
        if dataType.localizedCaseInsensitiveCompare("attachment") == .orderedSame {
            return "attachment"
        }
        return nil
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
