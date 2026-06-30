import Foundation

extension NativeEditorMarkdownParser {
    static func htmlTableMediaContentMatches(
        from html: String,
        excluding excludedRanges: [NSRange]
    ) -> [HTMLTableContentMatch] {
        let typedDivMatches = htmlTableTypedMediaDivContentMatches(from: html, excluding: excludedRanges)
        let typedDivRanges = excludedRanges + typedDivMatches.map(\.range)

        return htmlTableImageContentMatches(from: html, excluding: typedDivRanges) +
            htmlTableMediaElementContentMatches(from: html, excluding: typedDivRanges, type: "video") +
            htmlTableMediaElementContentMatches(from: html, excluding: typedDivRanges, type: "audio") +
            typedDivMatches
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
        switch type {
        case "pdf":
            let iframeAttrs = firstHTMLTagAttributes(in: body, tagName: "iframe") ?? [:]
            return htmlTablePDFNode(attrs: attrs, iframeAttrs: iframeAttrs)
        case "attachment":
            let linkAttrs = firstHTMLTagAttributes(in: body, tagName: "a") ?? [:]
            return htmlTableAttachmentNode(attrs: attrs, linkAttrs: linkAttrs)
        case "embed":
            let linkAttrs = firstHTMLTagAttributes(in: body, tagName: "a") ?? [:]
            return htmlTableEmbedNode(attrs: attrs, linkAttrs: linkAttrs)
        default:
            let imageAttrs = firstHTMLTagAttributes(in: body, tagName: "img") ?? [:]
            return htmlTableDiagramNode(type: type, attrs: attrs, imageAttrs: imageAttrs)
        }
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

    private static func htmlTableEmbedNode(
        attrs: [String: String],
        linkAttrs: [String: String]
    ) -> ProseMirrorNode {
        var nodeAttrs = [String: ProseMirrorJSONValue]()
        let source = nonEmptyHTMLTableAttribute(attrs["data-src"]) ?? nonEmptyHTMLTableAttribute(linkAttrs["href"])

        if let source {
            nodeAttrs["src"] = .string(source)
        }
        if let provider = nonEmptyHTMLTableAttribute(attrs["data-provider"]) {
            nodeAttrs["provider"] = .string(provider)
        }
        if let alignment = nonEmptyHTMLTableAttribute(attrs["data-align"]) {
            nodeAttrs["align"] = .string(alignment)
        }
        if let width = nonEmptyHTMLTableAttribute(attrs["data-width"]).flatMap(Int.init) {
            nodeAttrs["width"] = .int(width)
        }
        if let height = nonEmptyHTMLTableAttribute(attrs["data-height"]).flatMap(Int.init) {
            nodeAttrs["height"] = .int(height)
        }

        return ProseMirrorNode(type: "embed", attrs: nodeAttrs.isEmpty ? nil : nodeAttrs)
    }

    private static func htmlTableDiagramNode(
        type: String,
        attrs: [String: String],
        imageAttrs: [String: String]
    ) -> ProseMirrorNode {
        var nodeAttrs = [String: ProseMirrorJSONValue]()
        let source = nonEmptyHTMLTableAttribute(attrs["data-src"]) ?? nonEmptyHTMLTableAttribute(imageAttrs["src"])

        if let source {
            nodeAttrs["src"] = .string(source)
        }
        if let title = nonEmptyHTMLTableAttribute(attrs["data-title"]) {
            nodeAttrs["title"] = .string(title)
        }
        if let alternativeText = nonEmptyHTMLTableAttribute(attrs["data-alt"]) {
            nodeAttrs["alt"] = .string(alternativeText)
        }
        if let attachmentID = nonEmptyHTMLTableAttribute(attrs["data-attachment-id"]) ??
            source.flatMap(docmostAttachmentID) {
            nodeAttrs["attachmentId"] = .string(attachmentID)
        }
        if let sizeInBytes = nonEmptyHTMLTableAttribute(attrs["data-size"]).flatMap(Int.init) {
            nodeAttrs["size"] = .int(sizeInBytes)
        }
        let widthValue = nonEmptyHTMLTableAttribute(attrs["data-width"]) ??
            nonEmptyHTMLTableAttribute(imageAttrs["width"])
        if let width = widthValue.flatMap(htmlTableProseMirrorNumberOrString) {
            nodeAttrs["width"] = width
        }
        if let height = nonEmptyHTMLTableAttribute(attrs["data-height"]).flatMap(htmlTableProseMirrorNumberOrString) {
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

    private static func htmlTableTypedMediaDivType(from dataType: String?) -> String? {
        guard let dataType else { return nil }
        for supportedType in ["pdf", "attachment", "embed", "drawio", "excalidraw"]
            where dataType.localizedCaseInsensitiveCompare(supportedType) == .orderedSame {
            return supportedType
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
