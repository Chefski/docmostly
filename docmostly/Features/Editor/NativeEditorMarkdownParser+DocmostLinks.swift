import Foundation
import SwiftUI

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

    private struct DocmostCommentHTML {
        var range: Range<String.Index>
        var comment: NativeEditorInlineCommentMark
        var bodyMarkdown: String
    }

    static func appendMarkdownText(
        _ markdown: String,
        to result: inout AttributedString,
        usesFoundationMarkdownParser: Bool = true
    ) {
        guard markdown.isEmpty == false else { return }

        var remaining = markdown[...]
        var didAppendAtom = false
        while let htmlComment = nextDocmostCommentHTML(in: remaining) {
            appendMarkdownText(
                String(remaining[..<htmlComment.range.lowerBound]),
                to: &result,
                usesFoundationMarkdownParser: false
            )
            appendComment(htmlComment, to: &result)
            didAppendAtom = true
            remaining = remaining[htmlComment.range.upperBound...]
        }

        while let htmlStatus = nextDocmostStatusHTML(in: remaining) {
            appendMarkdownText(
                String(remaining[..<htmlStatus.range.lowerBound]),
                to: &result,
                usesFoundationMarkdownParser: false
            )
            appendStatus(htmlStatus.status, to: &result)
            didAppendAtom = true
            remaining = remaining[htmlStatus.range.upperBound...]
        }

        while let htmlHighlight = nextDocmostHighlightHTML(in: remaining) {
            appendMarkdownText(
                String(remaining[..<htmlHighlight.range.lowerBound]),
                to: &result,
                usesFoundationMarkdownParser: false
            )
            appendHighlight(htmlHighlight, to: &result)
            didAppendAtom = true
            remaining = remaining[htmlHighlight.range.upperBound...]
        }

        while let htmlTextColor = nextDocmostTextColorHTML(in: remaining) {
            appendMarkdownText(
                String(remaining[..<htmlTextColor.range.lowerBound]),
                to: &result,
                usesFoundationMarkdownParser: false
            )
            appendTextColor(htmlTextColor, to: &result)
            didAppendAtom = true
            remaining = remaining[htmlTextColor.range.upperBound...]
        }

        while let htmlInlineMark = nextDocmostScriptUnderlineHTML(in: remaining) {
            appendMarkdownText(
                String(remaining[..<htmlInlineMark.range.lowerBound]),
                to: &result,
                usesFoundationMarkdownParser: false
            )
            appendScriptUnderline(htmlInlineMark, to: &result)
            didAppendAtom = true
            remaining = remaining[htmlInlineMark.range.upperBound...]
        }

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

    static func commentMarkdown(from comments: [NativeEditorInlineCommentMark], body: String) -> String {
        comments.normalizedNativeEditorInlineComments.reversed().reduce(body) { markdown, comment in
            commentHTMLMarkdown(from: comment, body: markdown)
        }
    }

    private static func commentHTMLMarkdown(from comment: NativeEditorInlineCommentMark, body: String) -> String {
        let className = comment.isResolved ? "comment-mark resolved" : "comment-mark"
        let commentID = escapedInlineHTMLAttribute(comment.commentID)
        let resolvedAttribute = comment.isResolved ? #" data-resolved="true""# : ""
        return #"<span class="\#(className)" data-comment-id="\#(commentID)"\#(resolvedAttribute)>"#
            + body
            + "</span>"
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
            value.nonEmpty.map { "\(name)=\"\(escapedInlineHTMLAttribute($0))\"" }
        }.joined(separator: " ")

        let displayText = mentionHTMLDisplayText(from: mention, fallbackText: fallbackText)
        return "<span \(attrText)>\(escapedInlineHTMLText(displayText))</span>"
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

    private static func appendComment(_ htmlComment: DocmostCommentHTML, to result: inout AttributedString) {
        var commentBody = AttributedString("")
        appendMarkdownText(
            htmlComment.bodyMarkdown,
            to: &commentBody,
            usesFoundationMarkdownParser: false
        )
        applyComment(htmlComment.comment, to: &commentBody)
        result += commentBody
    }

    private static func applyComment(_ comment: NativeEditorInlineCommentMark, to text: inout AttributedString) {
        let ranges = text.runs.map(\.range)
        for range in ranges {
            let comments = text[range].nativeEditorInlineComments.updatingNativeEditorInlineComment(comment)
            text[range][NativeEditorCommentMarksAttribute.self] = comments.isEmpty ? nil : comments
            text[range][NativeEditorCommentIDAttribute.self] = comments.first?.commentID
            text[range][NativeEditorCommentResolvedAttribute.self] = comments.first?.isResolved
            text[range].backgroundColor = commentBackgroundColor(for: comments)
        }
    }

    private static func commentBackgroundColor(for comments: [NativeEditorInlineCommentMark]) -> Color? {
        guard comments.isEmpty == false else { return nil }
        return comments.contains { $0.isResolved == false }
            ? .yellow.opacity(0.28)
            : .gray.opacity(0.16)
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
            let attrs = docmostInlineHTMLAttributes(from: openingTag)
            guard attrs["data-type"] == "mention" else {
                searchStart = markdown.index(after: openRange.lowerBound)
                continue
            }

            let contentStart = markdown.index(after: openTagEnd)
            guard let closeRange = matchingCloseSpanRange(in: markdown, bodyStart: contentStart) else {
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

    private static func nextDocmostCommentHTML(in markdown: Substring) -> DocmostCommentHTML? {
        var searchStart = markdown.startIndex

        while searchStart < markdown.endIndex,
              let openRange = markdown[searchStart...].range(of: "<span", options: .caseInsensitive) {
            guard let openTagEnd = markdown[openRange.upperBound...].firstIndex(of: ">") else {
                return nil
            }

            let openingTag = String(markdown[openRange.lowerBound...openTagEnd])
            let attrs = docmostInlineHTMLAttributes(from: openingTag)
            guard let commentID = attrs["data-comment-id"]?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nonEmpty
            else {
                searchStart = markdown.index(after: openRange.lowerBound)
                continue
            }

            let contentStart = markdown.index(after: openTagEnd)
            guard let closeRange = matchingCloseSpanRange(in: markdown, bodyStart: contentStart) else {
                return nil
            }

            return DocmostCommentHTML(
                range: openRange.lowerBound..<closeRange.upperBound,
                comment: NativeEditorInlineCommentMark(
                    commentID: commentID,
                    isResolved: docmostCommentResolved(from: attrs["data-resolved"])
                ),
                bodyMarkdown: String(markdown[contentStart..<closeRange.lowerBound])
            )
        }

        return nil
    }

    private static func docmostCommentResolved(from value: String?) -> Bool {
        guard let value else { return false }

        let normalizedValue = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard normalizedValue.isEmpty == false else { return true }

        return normalizedValue != "false" && normalizedValue != "0"
    }

    private static func mention(from attrs: [String: String], fallbackHTMLText: String) -> NativeEditorMention {
        let entityType = attrs["data-entity-type"]?.nonEmpty
        let fallbackLabel = unescapedInlineHTMLText(fallbackHTMLText)
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
