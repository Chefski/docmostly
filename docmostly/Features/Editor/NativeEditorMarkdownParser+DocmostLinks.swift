import Foundation

extension NativeEditorMarkdownParser {
    private struct DocmostPageLink {
        var slugID: String
        var label: String
        var anchorID: String?
    }

    private struct DocmostMarkdownLink {
        var range: Range<String.Index>
        var label: String
        var pageLink: DocmostPageLink
    }

    private struct DocmostMentionHTML {
        var range: Range<String.Index>
        var mention: NativeEditorMention
    }

    static func appendMarkdownText(
        _ markdown: String,
        to result: inout AttributedString,
        usesFoundationMarkdownParser: Bool = true
    ) {
        guard markdown.isEmpty == false else { return }

        var remaining = markdown[...]
        var didAppendAtom = false
        while let htmlMention = nextDocmostMentionHTML(in: remaining) {
            appendMarkdownText(
                String(remaining[..<htmlMention.range.lowerBound]),
                to: &result,
                usesFoundationMarkdownParser: false
            )
            appendMention(htmlMention.mention, to: &result)
            didAppendAtom = true
            remaining = remaining[htmlMention.range.upperBound...]
        }

        while let link = nextDocmostPageMarkdownLink(in: remaining) {
            appendMarkdownTextWithBareDocmostPageLinks(
                String(remaining[..<link.range.lowerBound]),
                to: &result,
                usesFoundationMarkdownParser: false
            )
            appendMention(label: link.label, pageLink: link.pageLink, to: &result)
            didAppendAtom = true
            remaining = remaining[link.range.upperBound...]
        }

        appendMarkdownTextWithBareDocmostPageLinks(
            String(remaining),
            to: &result,
            usesFoundationMarkdownParser: usesFoundationMarkdownParser && didAppendAtom == false
        )
    }

    static func mentionMarkdown(from mention: NativeEditorMention, fallbackText: String) -> String {
        guard mention.entityType == "page" else {
            if mention.entityType == nil {
                return fallbackText
            }
            return mentionHTMLMarkdown(from: mention, fallbackText: fallbackText)
        }

        guard let slugID = mention.slugID, slugID.isEmpty == false else {
            return mentionHTMLMarkdown(from: mention, fallbackText: fallbackText)
        }

        let label = escapedMarkdownLinkText(mention.label ?? fallbackText)
        let anchor = mention.anchorID.map { "#\($0)" } ?? ""
        return "[\(label)](/p/\(slugID)\(anchor))"
    }

    private static func mentionHTMLMarkdown(from mention: NativeEditorMention, fallbackText: String) -> String {
        let attrs: [(String, String?)] = [
            ("data-type", "mention"),
            ("data-id", mention.identifier),
            ("data-label", mention.label),
            ("data-entity-type", mention.entityType),
            ("data-entity-id", mention.entityID),
            ("data-slug-id", mention.slugID),
            ("data-creator-id", mention.creatorID),
            ("data-anchor-id", mention.anchorID)
        ]
        let attrText = attrs.compactMap { name, value in
            value.nonEmpty.map { "\(name)=\"\(escapedMentionHTMLAttribute($0))\"" }
        }.joined(separator: " ")

        let displayText = mentionHTMLDisplayText(from: mention, fallbackText: fallbackText)
        return "<span \(attrText)>\(escapedMentionHTMLText(displayText))</span>"
    }

    private static func mentionHTMLDisplayText(from mention: NativeEditorMention, fallbackText: String) -> String {
        if mention.entityType == "user" {
            let label = mention.label ?? fallbackText.removingMentionTrigger.nonEmpty ?? mention.entityID
                ?? mention.identifier ?? "Mention"
            return "@\(label)"
        }

        return mention.label ?? fallbackText.nonEmpty ?? mention.entityID ?? mention.identifier ?? "Mention"
    }

    private static func appendMarkdownTextWithBareDocmostPageLinks(
        _ markdown: String,
        to result: inout AttributedString,
        usesFoundationMarkdownParser: Bool
    ) {
        guard markdown.isEmpty == false else { return }

        var remaining = markdown[...]
        var didAppendAtom = false
        while let link = nextBareDocmostPageLink(in: remaining) {
            appendPlainMarkdownText(
                String(remaining[..<link.range.lowerBound]),
                to: &result,
                usesFoundationMarkdownParser: false
            )
            appendMention(label: link.label, pageLink: link.pageLink, to: &result)
            didAppendAtom = true
            remaining = remaining[link.range.upperBound...]
        }

        appendPlainMarkdownText(
            String(remaining),
            to: &result,
            usesFoundationMarkdownParser: usesFoundationMarkdownParser && didAppendAtom == false
        )
    }

    private static func appendPlainMarkdownText(
        _ markdown: String,
        to result: inout AttributedString,
        usesFoundationMarkdownParser: Bool
    ) {
        guard markdown.isEmpty == false else { return }
        if usesFoundationMarkdownParser {
            result += (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
        } else {
            result += attributedInlineMarkdown(from: markdown)
        }
    }

    private static func appendMention(
        label: String,
        pageLink: DocmostPageLink,
        to result: inout AttributedString
    ) {
        let displayLabel = plainMarkdownText(from: label).trimmingCharacters(in: .whitespacesAndNewlines)
        let mention = NativeEditorMention(
            identifier: UUID().uuidString,
            label: displayLabel.isEmpty ? "Untitled" : displayLabel,
            entityType: "page",
            entityID: pageLink.slugID,
            slugID: pageLink.slugID,
            anchorID: pageLink.anchorID
        )
        var segment = AttributedString(mention.displayText)
        segment[NativeEditorMentionAttribute.self] = mention
        result += segment
    }

    private static func appendMention(_ mention: NativeEditorMention, to result: inout AttributedString) {
        var segment = AttributedString(mention.displayText)
        segment[NativeEditorMentionAttribute.self] = mention
        result += segment
    }

    private static func plainMarkdownText(from markdown: String) -> String {
        let attributedText = (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
        return String(attributedText.characters)
    }

    private static func nextDocmostPageMarkdownLink(in markdown: Substring) -> DocmostMarkdownLink? {
        var searchStart = markdown.startIndex

        while searchStart < markdown.endIndex,
              let openLabelIndex = markdown[searchStart...].firstIndex(of: "[") {
            if isImageMarkdownMarker(before: openLabelIndex, in: markdown) {
                searchStart = markdown.index(after: openLabelIndex)
                continue
            }

            guard
                let closeLabelIndex = markdown[markdown.index(after: openLabelIndex)...].firstIndex(of: "]"),
                markdown.index(after: closeLabelIndex) < markdown.endIndex,
                markdown[markdown.index(after: closeLabelIndex)] == "(",
                let closeDestinationIndex = markdown[
                    markdown.index(after: markdown.index(after: closeLabelIndex))...
                ].firstIndex(of: ")")
            else {
                return nil
            }

            let destinationStartIndex = markdown.index(after: markdown.index(after: closeLabelIndex))
            let destination = String(markdown[destinationStartIndex..<closeDestinationIndex])
            if let pageLink = docmostPageLink(from: destination) {
                let labelStartIndex = markdown.index(after: openLabelIndex)
                return DocmostMarkdownLink(
                    range: openLabelIndex..<markdown.index(after: closeDestinationIndex),
                    label: String(markdown[labelStartIndex..<closeLabelIndex]),
                    pageLink: pageLink
                )
            }

            searchStart = markdown.index(after: closeDestinationIndex)
        }

        return nil
    }

    private static func nextDocmostMentionHTML(in markdown: Substring) -> DocmostMentionHTML? {
        var searchStart = markdown.startIndex

        while searchStart < markdown.endIndex,
              let openRange = markdown[searchStart...].range(of: "<span", options: .caseInsensitive) {
            guard let openTagEnd = markdown[openRange.upperBound...].firstIndex(of: ">") else {
                return nil
            }

            let openingTag = String(markdown[openRange.lowerBound...openTagEnd])
            let attrs = mentionHTMLAttributes(from: openingTag)
            guard attrs["data-type"] == "mention" else {
                searchStart = markdown.index(after: openRange.lowerBound)
                continue
            }

            let contentStart = markdown.index(after: openTagEnd)
            guard let closeRange = markdown[contentStart...].range(of: "</span>", options: .caseInsensitive) else {
                return nil
            }

            let body = String(markdown[contentStart..<closeRange.lowerBound])
            return DocmostMentionHTML(
                range: openRange.lowerBound..<closeRange.upperBound,
                mention: mention(from: attrs, fallbackHTMLText: body)
            )
        }

        return nil
    }

    private static func mention(from attrs: [String: String], fallbackHTMLText: String) -> NativeEditorMention {
        let entityType = attrs["data-entity-type"]?.nonEmpty
        let fallbackLabel = unescapedMentionHTMLText(fallbackHTMLText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .removingMentionTrigger

        return NativeEditorMention(
            identifier: attrs["data-id"]?.nonEmpty,
            label: attrs["data-label"]?.nonEmpty ?? fallbackLabel.nonEmpty,
            entityType: entityType,
            entityID: attrs["data-entity-id"]?.nonEmpty,
            slugID: attrs["data-slug-id"]?.nonEmpty,
            creatorID: attrs["data-creator-id"]?.nonEmpty,
            anchorID: attrs["data-anchor-id"]?.nonEmpty
        )
    }

    private static func mentionHTMLAttributes(from openingTag: String) -> [String: String] {
        var attrs = [String: String]()
        var index = openingTag.startIndex

        while index < openingTag.endIndex {
            guard let nameRange = nextMentionHTMLAttributeNameRange(in: openingTag, startingAt: index) else {
                break
            }

            index = nameRange.upperBound
            skipMentionHTMLWhitespace(in: openingTag, index: &index)
            guard index < openingTag.endIndex, openingTag[index] == "=" else {
                continue
            }

            index = openingTag.index(after: index)
            skipMentionHTMLWhitespace(in: openingTag, index: &index)
            let value = mentionHTMLAttributeValue(in: openingTag, startingAt: &index)
            attrs[String(openingTag[nameRange]).lowercased()] = unescapedMentionHTMLText(value)
        }

        return attrs
    }

    private static func nextMentionHTMLAttributeNameRange(
        in text: String,
        startingAt index: String.Index
    ) -> Range<String.Index>? {
        var nameStart = index
        while nameStart < text.endIndex, text[nameStart].isMentionHTMLAttributeNameCharacter == false {
            nameStart = text.index(after: nameStart)
        }

        guard nameStart < text.endIndex else { return nil }

        var nameEnd = nameStart
        while nameEnd < text.endIndex, text[nameEnd].isMentionHTMLAttributeNameCharacter {
            nameEnd = text.index(after: nameEnd)
        }

        return nameStart..<nameEnd
    }

    private static func mentionHTMLAttributeValue(
        in text: String,
        startingAt index: inout String.Index
    ) -> String {
        guard index < text.endIndex else { return "" }

        if text[index] == "\"" || text[index] == "'" {
            let quote = text[index]
            let valueStart = text.index(after: index)
            guard let valueEnd = text[valueStart...].firstIndex(of: quote) else {
                index = text.endIndex
                return String(text[valueStart...])
            }

            index = text.index(after: valueEnd)
            return String(text[valueStart..<valueEnd])
        }

        let valueStart = index
        while index < text.endIndex, text[index].isWhitespace == false, text[index] != ">" {
            index = text.index(after: index)
        }

        return String(text[valueStart..<index])
    }

    private static func skipMentionHTMLWhitespace(in text: String, index: inout String.Index) {
        while index < text.endIndex, text[index].isWhitespace {
            index = text.index(after: index)
        }
    }

    private static func nextBareDocmostPageLink(in markdown: Substring) -> DocmostMarkdownLink? {
        var searchStart = markdown.startIndex

        while searchStart < markdown.endIndex,
              let tokenRange = nextMarkdownTokenRange(in: markdown, startingAt: searchStart) {
            let candidateRange = trimmedBareLinkRange(tokenRange, in: markdown)
            if candidateRange.isEmpty == false {
                let candidate = String(markdown[candidateRange])
                if let pageLink = docmostPageLink(from: candidate) {
                    return DocmostMarkdownLink(
                        range: candidateRange,
                        label: pageLink.label,
                        pageLink: pageLink
                    )
                }
            }

            searchStart = tokenRange.upperBound
        }

        return nil
    }

    private static func nextMarkdownTokenRange(
        in markdown: Substring,
        startingAt searchStart: String.Index
    ) -> Range<String.Index>? {
        var tokenStart = searchStart

        while tokenStart < markdown.endIndex, markdown[tokenStart].isWhitespace {
            tokenStart = markdown.index(after: tokenStart)
        }

        guard tokenStart < markdown.endIndex else { return nil }

        var tokenEnd = tokenStart
        while tokenEnd < markdown.endIndex, markdown[tokenEnd].isWhitespace == false {
            tokenEnd = markdown.index(after: tokenEnd)
        }

        return tokenStart..<tokenEnd
    }

    private static func trimmedBareLinkRange(
        _ range: Range<String.Index>,
        in markdown: Substring
    ) -> Range<String.Index> {
        var lowerBound = range.lowerBound
        var upperBound = range.upperBound

        while lowerBound < upperBound,
              markdown[lowerBound].isBareLinkBoundaryPunctuation {
            lowerBound = markdown.index(after: lowerBound)
        }

        while lowerBound < upperBound {
            let previousIndex = markdown.index(before: upperBound)
            guard markdown[previousIndex].isBareLinkBoundaryPunctuation else { break }
            upperBound = previousIndex
        }

        return lowerBound..<upperBound
    }

    private static func isImageMarkdownMarker(before index: String.Index, in markdown: Substring) -> Bool {
        guard index > markdown.startIndex else { return false }
        return markdown[markdown.index(before: index)] == "!"
    }

    private static func docmostPageLink(from destination: String) -> DocmostPageLink? {
        let source = markdownLinkDestination(from: destination)
        guard source.isEmpty == false else { return nil }

        let components = URLComponents(string: source)
        let path = components?.path ?? source.components(separatedBy: "#").first ?? source
        let anchorID = components?.fragment?
            .components(separatedBy: "#")
            .first
            .flatMap { $0.isEmpty ? nil : $0 }
        let pathComponents = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard
            let pageMarkerIndex = pathComponents.lastIndex(of: "p"),
            pathComponents.index(after: pageMarkerIndex) < pathComponents.endIndex
        else {
            return nil
        }

        let routeSlug = pathComponents[pathComponents.index(after: pageMarkerIndex)]
        let slugID = extractDocmostPageSlugID(from: routeSlug)
        guard slugID.isEmpty == false else { return nil }

        return DocmostPageLink(
            slugID: slugID,
            label: docmostPageLinkLabel(from: routeSlug, slugID: slugID),
            anchorID: anchorID
        )
    }

    private static func markdownLinkDestination(from destination: String) -> String {
        let trimmedDestination = destination.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedDestination.hasPrefix("<"),
           let closeIndex = trimmedDestination.firstIndex(of: ">") {
            let sourceStartIndex = trimmedDestination.index(after: trimmedDestination.startIndex)
            return String(trimmedDestination[sourceStartIndex..<closeIndex])
        }

        return trimmedDestination.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
    }

    private static func extractDocmostPageSlugID(from slug: String) -> String {
        if UUID(uuidString: slug) != nil {
            return slug
        }

        let parts = slug.split(separator: "-", omittingEmptySubsequences: true).map(String.init)
        return parts.count > 1 ? parts[parts.count - 1] : slug
    }

    private static func docmostPageLinkLabel(from routeSlug: String, slugID: String) -> String {
        let parts = routeSlug.split(separator: "-", omittingEmptySubsequences: true).map(String.init)
        guard parts.count > 1 else { return slugID }
        return parts.dropLast().joined(separator: "-")
    }

    private static func escapedMarkdownLinkText(_ text: String) -> String {
        text
            .replacing("\\", with: "\\\\")
            .replacing("[", with: "\\[")
            .replacing("]", with: "\\]")
    }

    private static func escapedMentionHTMLAttribute(_ text: String) -> String {
        escapedMentionHTMLText(text).replacing("\"", with: "&quot;")
    }

    private static func escapedMentionHTMLText(_ text: String) -> String {
        text
            .replacing("&", with: "&amp;")
            .replacing("<", with: "&lt;")
            .replacing(">", with: "&gt;")
    }

    private static func unescapedMentionHTMLText(_ text: String) -> String {
        text
            .replacing("&quot;", with: "\"")
            .replacing("&lt;", with: "<")
            .replacing("&gt;", with: ">")
            .replacing("&amp;", with: "&")
    }
}

private extension Character {
    var isBareLinkBoundaryPunctuation: Bool {
        switch self {
        case "(", ")", "[", "]", "<", ">", ",", ".", ";", ":", "\"", "'":
            true
        default:
            false
        }
    }

    var isMentionHTMLAttributeNameCharacter: Bool {
        isLetter || isNumber || self == "-" || self == "_" || self == ":"
    }
}

private extension Optional where Wrapped == String {
    var nonEmpty: String? {
        switch self {
        case .some(let value):
            value.nonEmpty
        case .none:
            nil
        }
    }
}

private extension String {
    var nonEmpty: String? {
        isEmpty ? nil : self
    }

    var removingMentionTrigger: String {
        hasPrefix("@") ? String(dropFirst()) : self
    }
}
