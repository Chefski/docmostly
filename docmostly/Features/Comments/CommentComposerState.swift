import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class CommentComposerState {
    var text: AttributedString
    var selection = AttributedTextSelection()

    init(body: CommentBody? = nil) {
        text = body?.attributedText ?? AttributedString("")
    }

    var body: CommentBody {
        CommentBody(attributedText: text)
    }

    var plainText: String {
        String(text.characters)
    }

    var isEmpty: Bool {
        body.isEmpty
    }

    var hasSelection: Bool {
        selection.hasSelectedRanges(in: text)
    }

    func reset(body: CommentBody? = nil) {
        text = body?.attributedText ?? AttributedString("")
        selection = AttributedTextSelection()
    }

    func toggle(_ format: CommentComposerFormat) {
        guard hasSelection else { return }
        let removesIntent = selectedRuns.allSatisfy { run in
            (run.inlinePresentationIntent ?? []).contains(format.presentationIntent)
        }
        var updatedSelection = selection
        text.transformAttributes(in: &updatedSelection) { attributes in
            var intent = attributes.inlinePresentationIntent ?? []
            if removesIntent {
                intent.remove(format.presentationIntent)
            } else {
                intent.insert(format.presentationIntent)
            }
            attributes.inlinePresentationIntent = intent.isEmpty ? nil : intent
        }
        selection = updatedSelection
    }

    func isActive(_ format: CommentComposerFormat) -> Bool {
        hasSelection && selectedRuns.allSatisfy { run in
            (run.inlinePresentationIntent ?? []).contains(format.presentationIntent)
        }
    }

    func applyLink(_ rawHref: String) throws {
        guard hasSelection else { throw CommentLinkValidationError.selectText }
        let trimmedHref = rawHref.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedHref.isEmpty {
            removeLink()
            return
        }

        let normalizedLink: (href: String, url: URL)?
        if let safeLink = NativeEditorDocument.normalizedSafeWebLink(from: trimmedHref) {
            normalizedLink = safeLink
        } else if let mailURL = NativeEditorDocument.safeLinkURL(from: trimmedHref), mailURL.scheme == "mailto" {
            normalizedLink = (trimmedHref, mailURL)
        } else {
            normalizedLink = nil
        }

        guard let normalizedLink else { throw CommentLinkValidationError.invalidURL }
        var updatedSelection = selection
        text.transformAttributes(in: &updatedSelection) { attributes in
            attributes[NativeEditorLinkAttribute.self] = NativeEditorLink(
                href: normalizedLink.href,
                isInternal: false
            )
            attributes.link = normalizedLink.url
        }
        selection = updatedSelection
    }

    func removeLink() {
        guard hasSelection else { return }
        var updatedSelection = selection
        text.transformAttributes(in: &updatedSelection) { attributes in
            attributes[NativeEditorLinkAttribute.self] = nil
            attributes.link = nil
        }
        selection = updatedSelection
    }

    func insertMention(_ user: DocmostMentionUserSuggestion, creatorID: String?) {
        let mention = NativeEditorMention(userSuggestion: user, creatorID: creatorID)
        var segment = AttributedString(mention.displayText)
        segment[NativeEditorMentionAttribute.self] = mention
        segment.foregroundColor = DocmostlyTheme.primary
        segment += AttributedString(" ")
        replaceActiveTrigger("@", with: segment)
    }

    func insertEmoji(_ emoji: CommentEmoji) {
        replaceActiveTrigger(":", with: AttributedString("\(emoji.symbol) "))
    }

    func activeQuery(after trigger: Character) -> String? {
        guard let triggerRange = activeTriggerRange(trigger) else { return nil }
        let queryStart = text.characters.index(after: triggerRange.lowerBound)
        return String(text.characters[queryStart..<triggerRange.upperBound])
    }

    private var selectedRuns: [AttributedString.Runs.Run] {
        guard case .ranges(let ranges) = selection.indices(in: text) else { return [] }
        return ranges.ranges.flatMap { range in
            Array(text[range].runs)
        }
    }

    private func replaceActiveTrigger(_ trigger: Character, with replacement: AttributedString) {
        if let triggerRange = activeTriggerRange(trigger) {
            replace(range: triggerRange, with: replacement)
        } else {
            replaceSelection(with: replacement)
        }
    }

    private func replaceSelection(with replacement: AttributedString) {
        let range: Range<AttributedString.Index>
        switch selection.indices(in: text) {
        case .ranges(let ranges):
            range = ranges.ranges.first ?? text.endIndex..<text.endIndex
        case .insertionPoint(let insertionPoint):
            range = insertionPoint..<insertionPoint
        }
        replace(range: range, with: replacement)
    }

    private func replace(range: Range<AttributedString.Index>, with replacement: AttributedString) {
        let insertionOffset = text.characters.distance(from: text.startIndex, to: range.lowerBound)
        text.replaceSubrange(range, with: replacement)
        let selectionOffset = insertionOffset + replacement.characters.count
        let insertionPoint = text.characters.index(text.startIndex, offsetBy: selectionOffset)
        selection = AttributedTextSelection(insertionPoint: insertionPoint)
    }

    private func activeTriggerRange(_ trigger: Character) -> Range<AttributedString.Index>? {
        let cursor: AttributedString.Index
        switch selection.indices(in: text) {
        case .ranges(let ranges):
            guard let range = ranges.ranges.first, range.isEmpty else { return nil }
            cursor = range.lowerBound
        case .insertionPoint(let insertionPoint):
            cursor = insertionPoint
        }

        let prefix = String(text.characters[text.startIndex..<cursor])
        guard let triggerIndex = prefix.lastIndex(of: trigger) else { return nil }
        let queryStart = prefix.index(after: triggerIndex)
        let query = prefix[queryStart...]
        guard query.allSatisfy({ $0.isWhitespace == false }), query.count <= 40 else { return nil }

        if triggerIndex > prefix.startIndex {
            let previousIndex = prefix.index(before: triggerIndex)
            guard prefix[previousIndex].isWhitespace || prefix[previousIndex].isPunctuation else { return nil }
        }

        let triggerOffset = prefix.distance(from: prefix.startIndex, to: triggerIndex)
        let lowerBound = text.characters.index(text.startIndex, offsetBy: triggerOffset)
        return lowerBound..<cursor
    }
}

nonisolated enum CommentLinkValidationError: LocalizedError, Equatable {
    case selectText
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .selectText:
            "Select the text you want to link."
        case .invalidURL:
            "Enter a valid web or email link."
        }
    }
}
