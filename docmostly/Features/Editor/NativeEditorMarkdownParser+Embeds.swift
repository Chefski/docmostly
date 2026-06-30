import Foundation

extension NativeEditorMarkdownParser {
    static func mediaHTMLBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        let line = lines[index]

        if let youtube = youtubeHTMLBlock(in: lines, startingAt: index) {
            return youtube
        }

        if let iframe = iframeHTMLBlock(in: lines, startingAt: index) {
            return iframe
        }

        if let image = imageHTMLBlock(from: line) {
            return (image, lines.index(after: index))
        }

        if let video = mediaElementHTMLBlock(in: lines, startingAt: index, type: "video") {
            return video
        }

        if let audio = mediaElementHTMLBlock(in: lines, startingAt: index, type: "audio") {
            return audio
        }

        return typedMediaDivHTMLBlock(in: lines, startingAt: index)
    }

    static func diagramHTMLBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        guard
            let attributes = htmlTagAttributes(from: lines[index], tagName: "div"),
            let type = diagramType(from: attributes["data-type"])
        else {
            return nil
        }

        var imageAttributes: [String: String] = [:]
        var currentIndex = index

        while currentIndex < lines.endIndex {
            let line = lines[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if let attrs = firstHTMLTagAttributes(in: line, tagName: "img") {
                imageAttributes = attrs
            }
            if containsHTMLClosingTag(in: line, tagName: "div") {
                let diagram = diagramBlock(from: attributes, imageAttributes: imageAttributes)
                let kind = diagramKind(type: type, diagram: diagram)
                return (
                    NativeEditorBlock(
                        kind: kind,
                        text: AttributedString(NativeEditorDocument.previewText(for: kind)),
                        alignment: .left,
                        rawNode: NativeEditorRichBlockNodeFactory.diagramNode(from: diagram, type: type)
                    ),
                    lines.index(after: currentIndex)
                )
            }
            currentIndex = lines.index(after: currentIndex)
        }

        return nil
    }

    static func mediaHTMLMarkdown(from media: NativeEditorMediaBlock, type: String) -> String? {
        guard mediaRequiresDocmostHTML(media, type: type) else { return nil }

        switch type {
        case "image":
            return imageHTMLMarkdown(from: media)
        case "video":
            return videoHTMLMarkdown(from: media)
        case "audio":
            return audioHTMLMarkdown(from: media)
        default:
            return nil
        }
    }

    static func pdfHTMLMarkdown(from pdf: NativeEditorPDFBlock) -> String? {
        guard pdfRequiresDocmostHTML(pdf) else { return nil }

        let openingTag = htmlTag("div", attributes: [
            ("data-type", "pdf"),
            ("src", pdf.source),
            ("data-name", pdf.name),
            ("data-attachment-id", pdf.attachmentID),
            ("data-size", pdf.sizeInBytes.map(String.init)),
            ("width", pdf.width),
            ("height", pdf.height)
        ])
        let frameTag = htmlTag("iframe", attributes: [
            ("src", pdf.source),
            ("width", pdf.width),
            ("height", pdf.height)
        ])

        return """
        \(openingTag)
        \(frameTag)</iframe>
        </div>
        """
    }

    static func attachmentHTMLMarkdown(from attachment: NativeEditorAttachmentBlock) -> String? {
        guard attachmentRequiresDocmostHTML(attachment) else { return nil }

        let openingTag = htmlTag("div", attributes: [
            ("data-type", "attachment"),
            ("data-attachment-url", attachment.url),
            ("data-attachment-name", attachment.name),
            ("data-attachment-mime", attachment.mimeType),
            ("data-attachment-size", attachment.sizeInBytes.map(String.init)),
            ("data-attachment-id", attachment.attachmentID)
        ])
        let linkTag = htmlTag("a", attributes: [
            ("href", attachment.url),
            ("class", "attachment"),
            ("target", "blank")
        ])
        let title = escapedInlineHTMLText(attachment.name ?? attachment.url ?? "Attachment")

        return """
        \(openingTag)
        \(linkTag)\(title)</a>
        </div>
        """
    }

    static func embedHTMLMarkdown(from embed: NativeEditorEmbedBlock) -> String? {
        guard embed.provider?.lowercased() != "iframe" else { return nil }
        guard embedRequiresDocmostHTML(embed) else { return nil }

        let openingTag = htmlTag("div", attributes: [
            ("data-type", "embed"),
            ("data-src", embed.source),
            ("data-provider", embed.provider),
            ("data-align", embed.alignment),
            ("data-width", embed.width),
            ("data-height", embed.height)
        ])
        let linkTag = htmlTag("a", attributes: [
            ("href", embed.source),
            ("target", "blank")
        ])
        let source = escapedInlineHTMLText(embed.source ?? "Embed")

        return """
        \(openingTag)
        \(linkTag)\(source)</a>
        </div>
        """
    }

    static func diagramMarkdown(from diagram: NativeEditorDiagramBlock, type: String) -> String {
        let openingTag = htmlTag("div", attributes: [
            ("data-type", type),
            ("data-src", diagram.source),
            ("data-title", diagram.title),
            ("data-alt", diagram.alternativeText),
            ("data-width", diagram.width),
            ("data-height", diagram.height),
            ("data-size", diagram.sizeInBytes.map(String.init)),
            ("data-aspect-ratio", diagram.aspectRatio),
            ("data-align", diagram.alignment),
            ("data-attachment-id", diagram.attachmentID)
        ])
        let imageTag = htmlTag("img", attributes: [
            ("src", diagram.source),
            ("alt", diagram.alternativeText ?? diagram.title),
            ("width", diagram.width)
        ])

        return """
        \(openingTag)
        \(imageTag)
        </div>
        """
    }

    private static func imageHTMLBlock(from line: String) -> NativeEditorBlock? {
        guard let attributes = htmlTagAttributes(from: line, tagName: "img") else {
            return nil
        }

        let media = mediaBlock(from: attributes, sourceAttributes: [:], type: "image")
        return htmlRichBlock(
            kind: .image(media),
            rawNode: NativeEditorRichBlockNodeFactory.mediaNode(from: media, type: "image")
        )
    }

    private static func mediaElementHTMLBlock(
        in lines: [String],
        startingAt index: Array<String>.Index,
        type: String
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        guard let attributes = htmlTagAttributes(from: lines[index], tagName: type) else {
            return nil
        }

        var sourceAttributes: [String: String] = [:]
        var currentIndex = index

        while currentIndex < lines.endIndex {
            let line = lines[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if let attributes = firstHTMLTagAttributes(in: line, tagName: "source") {
                sourceAttributes = attributes
            }

            if line.localizedCaseInsensitiveContains("</\(type)>") {
                let media = mediaBlock(from: attributes, sourceAttributes: sourceAttributes, type: type)
                return (
                    htmlRichBlock(
                        kind: type == "video" ? .video(media) : .audio(media),
                        rawNode: NativeEditorRichBlockNodeFactory.mediaNode(from: media, type: type)
                    ),
                    lines.index(after: currentIndex)
                )
            }

            currentIndex = lines.index(after: currentIndex)
        }

        return nil
    }

    private static func typedMediaDivHTMLBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        guard
            let attributes = htmlTagAttributes(from: lines[index], tagName: "div"),
            let type = mediaDivType(from: attributes["data-type"])
        else {
            return nil
        }

        var childAttributes: [String: String] = [:]
        var currentIndex = index
        var containerDepth = 0

        while currentIndex < lines.endIndex {
            let line = lines[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if let attributes = firstHTMLTagAttributes(in: line, tagName: type == "pdf" ? "iframe" : "a") {
                childAttributes = attributes
            }

            containerDepth += htmlTagDepthDelta(in: line, tagName: "div")
            if containerDepth <= 0 {
                let block = typedMediaDivBlock(type: type, attributes: attributes, childAttributes: childAttributes)
                return (block, lines.index(after: currentIndex))
            }

            currentIndex = lines.index(after: currentIndex)
        }

        return nil
    }

    private static func typedMediaDivBlock(
        type: String,
        attributes: [String: String],
        childAttributes: [String: String]
    ) -> NativeEditorBlock {
        switch type {
        case "pdf":
            let pdf = pdfBlock(from: attributes, iframeAttributes: childAttributes)
            return htmlRichBlock(kind: .pdf(pdf), rawNode: NativeEditorRichBlockNodeFactory.pdfNode(from: pdf))
        case "attachment":
            let attachment = attachmentBlock(from: attributes, linkAttributes: childAttributes)
            return htmlRichBlock(
                kind: .attachment(attachment),
                rawNode: NativeEditorRichBlockNodeFactory.attachmentNode(from: attachment)
            )
        default:
            let embed = embedBlock(from: attributes, linkAttributes: childAttributes)
            return htmlRichBlock(kind: .embed(embed), rawNode: NativeEditorRichBlockNodeFactory.embedNode(from: embed))
        }
    }

    private static func mediaBlock(
        from attributes: [String: String],
        sourceAttributes: [String: String],
        type: String
    ) -> NativeEditorMediaBlock {
        let source = nonEmptyHTMLAttribute(attributes["src"]) ?? nonEmptyHTMLAttribute(sourceAttributes["src"])
        return NativeEditorMediaBlock(
            source: source,
            alternativeText: mediaAlternativeText(from: attributes, type: type),
            title: nil,
            attachmentID: mediaAttachmentID(from: attributes, source: source),
            sizeInBytes: nonEmptyHTMLAttribute(attributes["data-size"]).flatMap(Int.init),
            width: nonEmptyHTMLAttribute(attributes["width"]),
            height: nonEmptyHTMLAttribute(attributes["height"]),
            aspectRatio: nonEmptyHTMLAttribute(attributes["data-aspect-ratio"]),
            alignment: nonEmptyHTMLAttribute(attributes["data-align"])
        )
    }

    private static func pdfBlock(
        from attributes: [String: String],
        iframeAttributes: [String: String]
    ) -> NativeEditorPDFBlock {
        let source = nonEmptyHTMLAttribute(attributes["src"]) ?? nonEmptyHTMLAttribute(iframeAttributes["src"])
        return NativeEditorPDFBlock(
            source: source,
            name: nonEmptyHTMLAttribute(attributes["data-name"]),
            attachmentID: mediaAttachmentID(from: attributes, source: source),
            sizeInBytes: nonEmptyHTMLAttribute(attributes["data-size"]).flatMap(Int.init),
            width: nonEmptyHTMLAttribute(attributes["width"]) ?? nonEmptyHTMLAttribute(iframeAttributes["width"]),
            height: nonEmptyHTMLAttribute(attributes["height"]) ?? nonEmptyHTMLAttribute(iframeAttributes["height"])
        )
    }

    private static func attachmentBlock(
        from attributes: [String: String],
        linkAttributes: [String: String]
    ) -> NativeEditorAttachmentBlock {
        let source = nonEmptyHTMLAttribute(attributes["data-attachment-url"]) ??
            nonEmptyHTMLAttribute(linkAttributes["href"])
        return NativeEditorAttachmentBlock(
            url: source,
            name: nonEmptyHTMLAttribute(attributes["data-attachment-name"]),
            mimeType: nonEmptyHTMLAttribute(attributes["data-attachment-mime"]),
            sizeInBytes: nonEmptyHTMLAttribute(attributes["data-attachment-size"]).flatMap(Int.init),
            attachmentID: mediaAttachmentID(from: attributes, source: source)
        )
    }

    private static func embedBlock(
        from attributes: [String: String],
        linkAttributes: [String: String]
    ) -> NativeEditorEmbedBlock {
        NativeEditorEmbedBlock(
            source: nonEmptyHTMLAttribute(attributes["data-src"]) ?? nonEmptyHTMLAttribute(linkAttributes["href"]),
            provider: nonEmptyHTMLAttribute(attributes["data-provider"]),
            alignment: nonEmptyHTMLAttribute(attributes["data-align"]),
            width: nonEmptyHTMLAttribute(attributes["data-width"]),
            height: nonEmptyHTMLAttribute(attributes["data-height"])
        )
    }

    private static func htmlRichBlock(kind: NativeEditorBlockKind, rawNode: ProseMirrorNode) -> NativeEditorBlock {
        NativeEditorBlock(
            kind: kind,
            text: AttributedString(NativeEditorDocument.previewText(for: kind)),
            alignment: .left,
            rawNode: rawNode
        )
    }

    private static func imageHTMLMarkdown(from media: NativeEditorMediaBlock) -> String {
        htmlTag("img", attributes: [
            ("src", media.source),
            ("alt", media.alternativeText),
            ("width", media.width),
            ("height", media.height),
            ("data-align", media.alignment),
            ("data-attachment-id", media.attachmentID),
            ("data-size", media.sizeInBytes.map(String.init)),
            ("data-aspect-ratio", media.aspectRatio)
        ])
    }

    private static func videoHTMLMarkdown(from media: NativeEditorMediaBlock) -> String {
        let openingTag = htmlTag("video", attributes: [
            ("controls", "true"),
            ("src", media.source),
            ("aria-label", media.alternativeText),
            ("data-attachment-id", media.attachmentID),
            ("width", media.width),
            ("height", media.height),
            ("data-size", media.sizeInBytes.map(String.init)),
            ("data-align", media.alignment),
            ("data-aspect-ratio", media.aspectRatio)
        ])
        let sourceTag = htmlTag("source", attributes: [("src", media.source)])

        return """
        \(openingTag)
        \(sourceTag)
        </video>
        """
    }

    private static func audioHTMLMarkdown(from media: NativeEditorMediaBlock) -> String {
        let openingTag = htmlTag("audio", attributes: [
            ("controls", "true"),
            ("preload", "metadata"),
            ("src", media.source),
            ("data-attachment-id", media.attachmentID),
            ("data-size", media.sizeInBytes.map(String.init))
        ])
        let sourceTag = htmlTag("source", attributes: [("src", media.source)])

        return """
        \(openingTag)
        \(sourceTag)
        </audio>
        """
    }

    private static func mediaRequiresDocmostHTML(_ media: NativeEditorMediaBlock, type: String) -> Bool {
        media.attachmentID != nil ||
            media.sizeInBytes != nil ||
            media.width != nil ||
            media.height != nil ||
            media.aspectRatio != nil ||
            media.alignment != nil ||
            (type == "video" && media.alternativeText != nil)
    }

    private static func pdfRequiresDocmostHTML(_ pdf: NativeEditorPDFBlock) -> Bool {
        pdf.attachmentID != nil ||
            pdf.sizeInBytes != nil ||
            pdf.width != nil ||
            pdf.height != nil
    }

    private static func attachmentRequiresDocmostHTML(_ attachment: NativeEditorAttachmentBlock) -> Bool {
        attachment.attachmentID != nil ||
            attachment.mimeType != nil ||
            attachment.sizeInBytes != nil
    }

    private static func embedRequiresDocmostHTML(_ embed: NativeEditorEmbedBlock) -> Bool {
        guard embed.provider?.lowercased() != "iframe" else { return false }

        return embed.provider != nil ||
            embed.alignment != nil ||
            embed.width != nil ||
            embed.height != nil
    }

    private static func mediaDivType(from dataType: String?) -> String? {
        guard let dataType else { return nil }
        return ["pdf", "attachment", "embed"].first {
            dataType.localizedCaseInsensitiveCompare($0) == .orderedSame
        }
    }

    private static func mediaAlternativeText(from attributes: [String: String], type: String) -> String? {
        if type == "video" {
            return nonEmptyHTMLAttribute(attributes["aria-label"]) ?? nonEmptyHTMLAttribute(attributes["alt"])
        }

        return nonEmptyHTMLAttribute(attributes["alt"])
    }

    private static func mediaAttachmentID(from attributes: [String: String], source: String?) -> String? {
        nonEmptyHTMLAttribute(attributes["data-attachment-id"]) ?? source.flatMap(docmostAttachmentID)
    }

    private static func htmlTag(_ name: String, attributes: [(String, String?)]) -> String {
        let attributeText = attributes.compactMap { key, value -> String? in
            guard let value = nonEmptyHTMLAttribute(value) else { return nil }
            return #"\#(key)="\#(escapedInlineHTMLAttribute(value))""#
        }.joined(separator: " ")

        return attributeText.isEmpty ? "<\(name)>" : "<\(name) \(attributeText)>"
    }

    private static func diagramType(from dataType: String?) -> String? {
        guard let dataType else { return nil }
        if dataType.localizedCaseInsensitiveCompare("drawio") == .orderedSame {
            return "drawio"
        }
        if dataType.localizedCaseInsensitiveCompare("excalidraw") == .orderedSame {
            return "excalidraw"
        }
        return nil
    }

    private static func diagramBlock(
        from attributes: [String: String],
        imageAttributes: [String: String]
    ) -> NativeEditorDiagramBlock {
        let source = nonEmptyHTMLAttribute(attributes["data-src"]) ?? nonEmptyHTMLAttribute(imageAttributes["src"])
        return NativeEditorDiagramBlock(
            source: source,
            title: nonEmptyHTMLAttribute(attributes["data-title"]),
            alternativeText: nonEmptyHTMLAttribute(attributes["data-alt"]),
            attachmentID: diagramAttachmentID(from: attributes, source: source),
            sizeInBytes: nonEmptyHTMLAttribute(attributes["data-size"]).flatMap(Int.init),
            width: nonEmptyHTMLAttribute(attributes["data-width"]) ?? nonEmptyHTMLAttribute(imageAttributes["width"]),
            height: nonEmptyHTMLAttribute(attributes["data-height"]),
            aspectRatio: nonEmptyHTMLAttribute(attributes["data-aspect-ratio"]),
            alignment: nonEmptyHTMLAttribute(attributes["data-align"])
        )
    }

    private static func diagramKind(type: String, diagram: NativeEditorDiagramBlock) -> NativeEditorBlockKind {
        type == "drawio" ? .drawio(diagram) : .excalidraw(diagram)
    }

    private static func diagramAttachmentID(from attributes: [String: String], source: String?) -> String? {
        nonEmptyHTMLAttribute(attributes["data-attachment-id"]) ?? source.flatMap(docmostAttachmentID)
    }

    private static func nonEmptyHTMLAttribute(_ value: String?) -> String? {
        guard let value, value.isEmpty == false else {
            return nil
        }
        return value
    }
}
