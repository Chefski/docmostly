import Foundation

extension NativeEditorMarkdownParser {
    static func richBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        if let mathBlock = mathFenceBlock(in: lines, startingAt: index) {
            return mathBlock
        }

        if let calloutBlock = calloutFenceBlock(in: lines, startingAt: index) {
            return calloutBlock
        }

        return detailsHTMLBlock(in: lines, startingAt: index)
    }

    static func singleLineRichBlock(from line: String) -> NativeEditorBlock? {
        imageMarkdownBlock(from: line)
    }

    static func richMarkdownLine(from block: NativeEditorBlock) -> String? {
        if let mediaMarkdown = mediaMarkdownLine(from: block) {
            return mediaMarkdown
        }

        if let structuralMarkdown = structuralMarkdownLine(from: block) {
            return structuralMarkdown
        }

        return embeddedMarkdownLine(from: block)
    }

    private static func mediaMarkdownLine(from block: NativeEditorBlock) -> String? {
        switch block.kind {
        case .image(let media):
            imageMarkdown(from: media)
        case .video(let media):
            mediaLinkMarkdown(from: media, fallbackTitle: "Video")
        case .audio(let media):
            mediaLinkMarkdown(from: media, fallbackTitle: "Audio")
        case .pdf(let pdf):
            linkMarkdown(title: pdf.name ?? pdf.source ?? "PDF", url: pdf.source)
        case .attachment(let attachment):
            linkMarkdown(title: attachment.name ?? attachment.url ?? "Attachment", url: attachment.url)
        default:
            nil
        }
    }

    private static func structuralMarkdownLine(from block: NativeEditorBlock) -> String? {
        switch block.kind {
        case .callout(let callout):
            calloutMarkdown(from: callout)
        case .details(let details):
            detailsMarkdown(from: details)
        case .pageBreak:
            #"<div style="page-break-after: always;"></div>"#
        case .columns(let columns):
            columnsMarkdown(from: columns)
        case .subpages:
            "<!-- Docmost subpages block -->"
        case .transclusionSource(let source):
            transclusionSourceMarkdown(from: source)
        case .transclusionReference(let reference):
            transclusionReferenceMarkdown(from: reference)
        default:
            nil
        }
    }

    private static func embeddedMarkdownLine(from block: NativeEditorBlock) -> String? {
        switch block.kind {
        case .embed(let embed):
            linkMarkdown(title: embed.provider ?? embed.source ?? "Embed", url: embed.source)
        case .drawio(let diagram):
            diagramMarkdown(from: diagram, fallbackTitle: "Draw.io diagram")
        case .excalidraw(let diagram):
            diagramMarkdown(from: diagram, fallbackTitle: "Excalidraw diagram")
        case .mathBlock(let math):
            mathMarkdown(from: math)
        case .unsupported:
            String(block.text.characters)
        default:
            nil
        }
    }

    private static func mathFenceBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        guard lines[index].trimmingCharacters(in: .whitespaces) == "$$" else { return nil }

        var content: [String] = []
        var currentIndex = lines.index(after: index)

        while currentIndex < lines.endIndex {
            let line = lines[currentIndex]
            if line.trimmingCharacters(in: .whitespaces) == "$$" {
                let math = NativeEditorMathBlock(text: content.joined(separator: "\n").trimmedMarkdownBlockText)
                return (
                    richBlock(
                        kind: .mathBlock(math),
                        rawNode: NativeEditorRichBlockNodeFactory.mathBlockNode(from: math)
                    ),
                    lines.index(after: currentIndex)
                )
            }

            content.append(line)
            currentIndex = lines.index(after: currentIndex)
        }

        return nil
    }

    private static func calloutFenceBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        let line = lines[index].trimmingCharacters(in: .whitespaces)
        guard line.hasPrefix(":::") else { return nil }

        let header = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        guard header.isEmpty == false else { return nil }

        let headerParts = header.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let styleText = headerParts.first else { return nil }

        var content = headerParts.dropFirst().map(String.init)
        var currentIndex = lines.index(after: index)

        while currentIndex < lines.endIndex {
            let currentLine = lines[currentIndex]
            if currentLine.trimmingCharacters(in: .whitespaces) == ":::" {
                let callout = NativeEditorCalloutBlock(
                    style: sanitizedCalloutStyle(String(styleText)),
                    icon: nil,
                    previewText: content.joined(separator: "\n").trimmedMarkdownBlockText
                )
                return (
                    richBlock(
                        kind: .callout(callout),
                        rawNode: NativeEditorRichBlockNodeFactory.calloutNode(from: callout)
                    ),
                    lines.index(after: currentIndex)
                )
            }

            content.append(currentLine)
            currentIndex = lines.index(after: currentIndex)
        }

        return nil
    }

    private static func detailsHTMLBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        let line = lines[index].trimmingCharacters(in: .whitespaces)
        guard line.localizedCaseInsensitiveCompare("<details>") == .orderedSame else {
            return nil
        }

        var summary = "Details"
        var body: [String] = []
        var currentIndex = lines.index(after: index)

        while currentIndex < lines.endIndex {
            let line = lines[currentIndex]
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.localizedCaseInsensitiveCompare("</details>") == .orderedSame {
                let details = NativeEditorDetailsBlock(
                    summary: summary,
                    previewText: body.joined(separator: "\n").trimmedMarkdownBlockText,
                    isOpen: true
                )
                return (
                    richBlock(
                        kind: .details(details),
                        rawNode: NativeEditorRichBlockNodeFactory.detailsNode(from: details)
                    ),
                    lines.index(after: currentIndex)
                )
            }

            if let parsedSummary = summaryText(from: trimmedLine) {
                summary = parsedSummary
            } else {
                body.append(line)
            }
            currentIndex = lines.index(after: currentIndex)
        }

        return nil
    }

    private static func imageMarkdownBlock(from line: String) -> NativeEditorBlock? {
        guard
            line.hasPrefix("!["),
            let closeAltIndex = line.firstIndex(of: "]")
        else {
            return nil
        }

        let openDestinationIndex = line.index(after: closeAltIndex)
        guard
            openDestinationIndex < line.endIndex,
            line[openDestinationIndex] == "(",
            let closeDestinationIndex = line.lastIndex(of: ")"),
            closeDestinationIndex > openDestinationIndex
        else {
            return nil
        }

        let altStartIndex = line.index(line.startIndex, offsetBy: 2)
        let altText = unescapedMarkdownLinkText(String(line[altStartIndex..<closeAltIndex]))
        let destinationStartIndex = line.index(after: openDestinationIndex)
        let destination = String(line[destinationStartIndex..<closeDestinationIndex])
        let source = markdownLinkSource(from: destination)
        guard source.isEmpty == false else { return nil }

        let media = NativeEditorMediaBlock(
            source: source,
            alternativeText: altText.isEmpty ? nil : altText,
            title: nil,
            attachmentID: nil,
            sizeInBytes: nil,
            width: nil,
            height: nil,
            aspectRatio: nil,
            alignment: nil
        )

        return richBlock(
            kind: .image(media),
            rawNode: NativeEditorRichBlockNodeFactory.mediaNode(from: media, type: "image")
        )
    }

    private static func richBlock(kind: NativeEditorBlockKind, rawNode: ProseMirrorNode) -> NativeEditorBlock {
        NativeEditorBlock(
            kind: kind,
            text: AttributedString(NativeEditorDocument.previewText(for: kind)),
            alignment: .left,
            rawNode: rawNode
        )
    }

    private static func imageMarkdown(from media: NativeEditorMediaBlock) -> String {
        guard let source = media.source, source.isEmpty == false else {
            return media.alternativeText ?? "Image"
        }

        return "![\(escapedMarkdownLinkText(media.alternativeText ?? ""))](\(source))"
    }

    private static func mediaLinkMarkdown(from media: NativeEditorMediaBlock, fallbackTitle: String) -> String {
        linkMarkdown(title: media.alternativeText ?? media.title ?? media.source ?? fallbackTitle, url: media.source)
    }

    private static func calloutMarkdown(from callout: NativeEditorCalloutBlock) -> String {
        """
        :::\(sanitizedCalloutStyle(callout.style))
        \(callout.previewText.trimmedMarkdownBlockText)
        :::
        """
    }

    private static func detailsMarkdown(from details: NativeEditorDetailsBlock) -> String {
        """
        <details>
        <summary>\(escapedHTMLText(details.summary))</summary>

        \(details.previewText.trimmedMarkdownBlockText)

        </details>
        """
    }

    private static func columnsMarkdown(from columns: NativeEditorColumnsBlock) -> String {
        let columnTexts = columns.columnTexts.isEmpty ? [columns.previewText] : columns.columnTexts
        return columnTexts.enumerated().map { index, text in
            "### Column \(index + 1)\n\(text.trimmedMarkdownBlockText)"
        }.joined(separator: "\n\n")
    }

    private static func transclusionSourceMarkdown(from source: NativeEditorTransclusionSourceBlock) -> String {
        if let identifier = source.identifier, identifier.isEmpty == false {
            return "<!-- Docmost synced block: \(identifier) -->\n\(source.previewText.trimmedMarkdownBlockText)"
        }

        return source.previewText.trimmedMarkdownBlockText
    }

    private static func transclusionReferenceMarkdown(
        from reference: NativeEditorTransclusionReferenceBlock
    ) -> String {
        let identifier = reference.transclusionID ?? reference.sourcePageID ?? "unknown"
        return "<!-- Docmost synced block reference: \(identifier) -->"
    }

    private static func diagramMarkdown(from diagram: NativeEditorDiagramBlock, fallbackTitle: String) -> String {
        linkMarkdown(
            title: diagram.title ?? diagram.alternativeText ?? diagram.source ?? fallbackTitle,
            url: diagram.source
        )
    }

    private static func mathMarkdown(from math: NativeEditorMathBlock) -> String {
        """
        $$
        \(math.text.trimmedMarkdownBlockText)
        $$
        """
    }

    private static func linkMarkdown(title: String, url: String?) -> String {
        guard let url, url.isEmpty == false else { return title }
        return "[\(escapedMarkdownLinkText(title))](\(url))"
    }

    private static func sanitizedCalloutStyle(_ value: String) -> String {
        let sanitizedScalars = value.lowercased().unicodeScalars.filter {
            CharacterSet.alphanumerics.contains($0)
        }
        let sanitized = String(String.UnicodeScalarView(sanitizedScalars))
        return sanitized.isEmpty ? "info" : sanitized
    }

    private static func summaryText(from line: String) -> String? {
        guard
            line.localizedCaseInsensitiveContains("<summary>"),
            line.localizedCaseInsensitiveContains("</summary>")
        else {
            return nil
        }

        let lowercasedLine = line.lowercased()
        guard
            let startRange = lowercasedLine.range(of: "<summary>"),
            let endRange = lowercasedLine.range(of: "</summary>")
        else {
            return nil
        }

        let contentStartOffset = lowercasedLine.distance(
            from: lowercasedLine.startIndex,
            to: startRange.upperBound
        )
        let contentEndOffset = lowercasedLine.distance(
            from: lowercasedLine.startIndex,
            to: endRange.lowerBound
        )
        let contentStart = line.index(line.startIndex, offsetBy: contentStartOffset)
        let contentEnd = line.index(line.startIndex, offsetBy: contentEndOffset)
        guard contentStart <= contentEnd else { return nil }
        return unescapedHTMLText(String(line[contentStart..<contentEnd]))
    }

    private static func markdownLinkSource(from destination: String) -> String {
        var source = destination.trimmingCharacters(in: .whitespacesAndNewlines)

        if source.hasPrefix("<"), source.hasSuffix(">") {
            source.removeFirst()
            source.removeLast()
        }

        if let titleRange = source.range(of: " \"") {
            source = String(source[..<titleRange.lowerBound])
        }

        return source.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func escapedMarkdownLinkText(_ text: String) -> String {
        text.replacing("\\", with: "\\\\")
            .replacing("[", with: "\\[")
            .replacing("]", with: "\\]")
            .replacing("!", with: "\\!")
            .replacing("\r", with: " ")
            .replacing("\n", with: " ")
    }

    private static func unescapedMarkdownLinkText(_ text: String) -> String {
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

        if isEscaped {
            result.append("\\")
        }

        return result
    }

    private static func escapedHTMLText(_ text: String) -> String {
        text.replacing("&", with: "&amp;")
            .replacing("<", with: "&lt;")
            .replacing(">", with: "&gt;")
    }

    private static func unescapedHTMLText(_ text: String) -> String {
        text.replacing("&lt;", with: "<")
            .replacing("&gt;", with: ">")
            .replacing("&amp;", with: "&")
    }
}

private extension String {
    var trimmedMarkdownBlockText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
