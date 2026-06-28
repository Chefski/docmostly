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

    static func appendMarkdownText(_ markdown: String, to result: inout AttributedString) {
        guard markdown.isEmpty == false else { return }

        var remaining = markdown[...]
        while let link = nextDocmostPageMarkdownLink(in: remaining) {
            appendMarkdownTextWithBareDocmostPageLinks(String(remaining[..<link.range.lowerBound]), to: &result)
            appendMention(label: link.label, pageLink: link.pageLink, to: &result)
            remaining = remaining[link.range.upperBound...]
        }

        appendMarkdownTextWithBareDocmostPageLinks(String(remaining), to: &result)
    }

    static func mentionMarkdown(from mention: NativeEditorMention, fallbackText: String) -> String {
        guard mention.entityType == "page", let slugID = mention.slugID, slugID.isEmpty == false else {
            return fallbackText
        }

        let label = escapedMarkdownLinkText(mention.label ?? fallbackText)
        let anchor = mention.anchorID.map { "#\($0)" } ?? ""
        return "[\(label)](/p/\(slugID)\(anchor))"
    }

    private static func appendMarkdownTextWithBareDocmostPageLinks(
        _ markdown: String,
        to result: inout AttributedString
    ) {
        guard markdown.isEmpty == false else { return }

        var remaining = markdown[...]
        while let link = nextBareDocmostPageLink(in: remaining) {
            appendPlainMarkdownText(String(remaining[..<link.range.lowerBound]), to: &result)
            appendMention(label: link.label, pageLink: link.pageLink, to: &result)
            remaining = remaining[link.range.upperBound...]
        }

        appendPlainMarkdownText(String(remaining), to: &result)
    }

    private static func appendPlainMarkdownText(_ markdown: String, to result: inout AttributedString) {
        guard markdown.isEmpty == false else { return }
        result += (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
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
}
