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

        if let mediaBlock = mediaHTMLBlock(in: lines, startingAt: index) {
            return mediaBlock
        }

        if let diagramBlock = diagramHTMLBlock(in: lines, startingAt: index) {
            return diagramBlock
        }

        if let structuralBlock = docmostStructuralHTMLBlock(in: lines, startingAt: index) {
            return structuralBlock
        }

        if let columnsBlock = columnsHTMLBlock(in: lines, startingAt: index) {
            return columnsBlock
        }

        return detailsHTMLBlock(in: lines, startingAt: index)
    }

    static func singleLineRichBlock(from line: String) -> NativeEditorBlock? {
        pageBreakHTMLBlock(from: line) ?? imageMarkdownBlock(from: line) ?? linkedFileMarkdownBlock(from: line) ??
            iframeEmbedMarkdownBlock(from: line)
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
            mediaHTMLMarkdown(from: media, type: "image") ?? imageMarkdown(from: media)
        case .video(let media):
            mediaHTMLMarkdown(from: media, type: "video") ?? mediaLinkMarkdown(from: media, fallbackTitle: "Video")
        case .audio(let media):
            mediaHTMLMarkdown(from: media, type: "audio") ?? mediaLinkMarkdown(from: media, fallbackTitle: "Audio")
        case .pdf(let pdf):
            pdfHTMLMarkdown(from: pdf) ?? linkMarkdown(title: pdf.name ?? pdf.source ?? "PDF", url: pdf.source)
        case .attachment(let attachment):
            attachmentHTMLMarkdown(from: attachment) ??
                linkMarkdown(title: attachment.name ?? attachment.url ?? "Attachment", url: attachment.url)
        default:
            nil
        }
    }

    private static func structuralMarkdownLine(from block: NativeEditorBlock) -> String? {
        if let structuralHTML = docmostStructuralHTMLMarkdown(from: block) {
            return structuralHTML
        }

        return switch block.kind {
        case .callout(let callout):
            calloutMarkdown(from: callout)
        case .details(let details):
            detailsMarkdown(from: details)
        case .pageBreak:
            #"<div data-type="pageBreak" class="page-break"></div>"#
        case .columns(let columns):
            columnsMarkdown(from: columns)
        default:
            nil
        }
    }

    private static func embeddedMarkdownLine(from block: NativeEditorBlock) -> String? {
        switch block.kind {
        case .embed(let embed):
            embedHTMLMarkdown(from: embed) ?? embedMarkdown(from: embed)
        case .drawio(let diagram):
            diagramMarkdown(from: diagram, type: "drawio")
        case .excalidraw(let diagram):
            diagramMarkdown(from: diagram, type: "excalidraw")
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
        let title = markdownLinkTitle(from: destination)
        let attachmentID = docmostAttachmentID(from: source)
        guard source.isEmpty == false else { return nil }

        let media = NativeEditorMediaBlock(
            source: source,
            alternativeText: altText.isEmpty ? nil : altText,
            title: title,
            attachmentID: attachmentID,
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

    private static func linkedFileMarkdownBlock(from line: String) -> NativeEditorBlock? {
        guard
            line.hasPrefix("["),
            let closeTitleIndex = line.firstIndex(of: "]")
        else {
            return nil
        }

        let openDestinationIndex = line.index(after: closeTitleIndex)
        guard
            openDestinationIndex < line.endIndex,
            line[openDestinationIndex] == "(",
            let closeDestinationIndex = line.lastIndex(of: ")"),
            closeDestinationIndex == line.index(before: line.endIndex)
        else {
            return nil
        }

        let titleStartIndex = line.index(after: line.startIndex)
        let title = unescapedMarkdownLinkText(String(line[titleStartIndex..<closeTitleIndex]))
        let destinationStartIndex = line.index(after: openDestinationIndex)
        let source = markdownLinkSource(from: String(line[destinationStartIndex..<closeDestinationIndex]))
        guard source.isEmpty == false, let kind = linkedFileBlockKind(title: title, source: source) else {
            return nil
        }

        return linkedFileBlock(kind: kind)
    }

    private static func linkedFileBlockKind(title: String, source: String) -> NativeEditorBlockKind? {
        guard let fileExtension = markdownLinkFileExtension(from: source) else { return nil }
        let title = title.isEmpty ? nil : title
        let attachmentID = docmostAttachmentID(from: source)

        if videoFileExtensions.contains(fileExtension) {
            return .video(NativeEditorMediaBlock(
                source: source,
                alternativeText: nil,
                title: title,
                attachmentID: attachmentID,
                sizeInBytes: nil,
                width: nil,
                height: nil,
                aspectRatio: nil,
                alignment: nil
            ))
        }

        if audioFileExtensions.contains(fileExtension) {
            return .audio(NativeEditorMediaBlock(
                source: source,
                alternativeText: nil,
                title: title,
                attachmentID: attachmentID,
                sizeInBytes: nil,
                width: nil,
                height: nil,
                aspectRatio: nil,
                alignment: nil
            ))
        }

        if fileExtension == "pdf" {
            return .pdf(NativeEditorPDFBlock(
                source: source,
                name: title,
                attachmentID: attachmentID,
                sizeInBytes: nil,
                width: nil,
                height: nil
            ))
        }

        return .attachment(NativeEditorAttachmentBlock(
            url: source,
            name: title,
            mimeType: nil,
            sizeInBytes: nil,
            attachmentID: attachmentID
        ))
    }

    private static func linkedFileBlock(kind: NativeEditorBlockKind) -> NativeEditorBlock {
        switch kind {
        case .video(let media):
            richBlock(kind: kind, rawNode: NativeEditorRichBlockNodeFactory.mediaNode(from: media, type: "video"))
        case .audio(let media):
            richBlock(kind: kind, rawNode: NativeEditorRichBlockNodeFactory.mediaNode(from: media, type: "audio"))
        case .pdf(let pdf):
            richBlock(kind: kind, rawNode: NativeEditorRichBlockNodeFactory.pdfNode(from: pdf))
        case .attachment(let attachment):
            richBlock(kind: kind, rawNode: NativeEditorRichBlockNodeFactory.attachmentNode(from: attachment))
        default:
            richBlock(kind: kind, rawNode: ProseMirrorNode(type: "paragraph"))
        }
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

        let titlePart = markdownLinkTitlePart(from: media.title)
        return "![\(escapedMarkdownLinkText(media.alternativeText ?? ""))](\(source)\(titlePart))"
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

    private static func embedMarkdown(from embed: NativeEditorEmbedBlock) -> String {
        if embed.provider == "iframe", let source = embed.source, source.isEmpty == false {
            return linkMarkdown(title: source, url: source)
        }

        return linkMarkdown(title: embed.provider ?? embed.source ?? "Embed", url: embed.source)
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

    private static func markdownLinkFileExtension(from source: String) -> String? {
        let path = markdownLinkPath(from: source)
        guard
            let fileExtension = path.split(separator: ".").last?.lowercased(),
            fileExtension != path.lowercased()
        else {
            return nil
        }

        return fileExtension
    }

    static func docmostAttachmentID(from source: String) -> String? {
        let pathComponents = markdownLinkPath(from: source)
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        guard
            let apiIndex = pathComponents.firstIndex(of: "api"),
            pathComponents.indices.contains(pathComponents.index(after: apiIndex))
        else {
            return nil
        }

        let filesIndex = pathComponents.index(after: apiIndex)
        guard pathComponents[filesIndex] == "files" else { return nil }

        let attachmentIndex = pathComponents.index(after: filesIndex)
        guard pathComponents.indices.contains(attachmentIndex) else { return nil }

        let attachmentID = pathComponents[attachmentIndex]
        guard attachmentID.isEmpty == false else { return nil }
        return attachmentID.removingPercentEncoding ?? attachmentID
    }

    private static func markdownLinkPath(from source: String) -> String {
        let pathSource: String
        if let components = URLComponents(string: source), components.scheme != nil {
            pathSource = components.path.nonEmpty ?? ""
        } else {
            pathSource = source
        }

        return pathSource.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false)
            .first?
            .split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? pathSource
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

    private static var videoFileExtensions: Set<String> {
        ["avi", "m4v", "mkv", "mov", "mp4", "webm"]
    }

    private static var audioFileExtensions: Set<String> {
        ["aac", "aiff", "flac", "m4a", "mp3", "ogg", "opus", "wav"]
    }
}

private extension String {
    var trimmedMarkdownBlockText: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nonEmpty: String? {
        isEmpty ? nil : self
    }
}
