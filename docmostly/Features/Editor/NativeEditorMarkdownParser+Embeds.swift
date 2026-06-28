import Foundation

extension NativeEditorMarkdownParser {
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
        var currentIndex = lines.index(after: index)

        while currentIndex < lines.endIndex {
            let line = lines[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if let attrs = htmlTagAttributes(from: line, tagName: "img") {
                imageAttributes = attrs
            }
            if line.localizedCaseInsensitiveCompare("</div>") == .orderedSame {
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

    static func iframeEmbedMarkdownBlock(from line: String) -> NativeEditorBlock? {
        guard let link = iframeMarkdownLink(from: line), isWebEmbedSource(link.source) else {
            return nil
        }

        let embed = NativeEditorEmbedBlock(
            source: link.source,
            provider: "iframe",
            alignment: nil,
            width: nil,
            height: nil
        )
        return NativeEditorBlock(
            kind: .embed(embed),
            text: AttributedString(link.source),
            alignment: .left,
            rawNode: NativeEditorRichBlockNodeFactory.embedNode(from: embed)
        )
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

    private static func iframeMarkdownLink(from line: String) -> (label: String, source: String)? {
        guard line.hasPrefix("["), let closeLabelIndex = line.firstIndex(of: "]") else {
            return nil
        }

        let openDestinationIndex = line.index(after: closeLabelIndex)
        guard
            openDestinationIndex < line.endIndex,
            line[openDestinationIndex] == "(",
            let closeDestinationIndex = line.lastIndex(of: ")"),
            closeDestinationIndex == line.index(before: line.endIndex)
        else {
            return nil
        }

        let labelStartIndex = line.index(after: line.startIndex)
        let label = unescapedMarkdownLinkLabel(String(line[labelStartIndex..<closeLabelIndex]))
        let destinationStartIndex = line.index(after: openDestinationIndex)
        let source = markdownEmbedSource(from: String(line[destinationStartIndex..<closeDestinationIndex]))
        guard label == source else { return nil }
        return (label, source)
    }

    private static func markdownEmbedSource(from destination: String) -> String {
        var source = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        if source.hasPrefix("<"), source.hasSuffix(">") {
            source.removeFirst()
            source.removeLast()
        }
        return source.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func unescapedMarkdownLinkLabel(_ text: String) -> String {
        var result = ""
        var isEscaped = false

        for character in text {
            if isEscaped {
                result.append(character)
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else {
                result.append(character)
            }
        }

        return isEscaped ? result + "\\" : result
    }

    private static func isWebEmbedSource(_ source: String) -> Bool {
        guard
            let components = URLComponents(string: source),
            let scheme = components.scheme?.lowercased(),
            scheme == "https" || scheme == "http",
            components.host?.isEmpty == false
        else {
            return false
        }

        return true
    }

    private static func htmlTag(_ name: String, attributes: [(String, String?)]) -> String {
        let attributeText = attributes.compactMap { key, value -> String? in
            guard let value = nonEmptyHTMLAttribute(value) else { return nil }
            return #"\#(key)="\#(escapedInlineHTMLAttribute(value))""#
        }.joined(separator: " ")

        return attributeText.isEmpty ? "<\(name)>" : "<\(name) \(attributeText)>"
    }

    private static func htmlTagAttributes(from line: String, tagName: String) -> [String: String]? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedLine.lowercased().hasPrefix("<\(tagName.lowercased())") else { return nil }
        guard let tagEnd = trimmedLine.firstIndex(of: ">"), tagEnd > trimmedLine.startIndex else {
            return nil
        }

        let openingTag = String(trimmedLine[trimmedLine.startIndex..<tagEnd])
        return docmostInlineHTMLAttributes(from: openingTag)
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
