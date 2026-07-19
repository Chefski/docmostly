import Foundation
import SwiftUI

nonisolated struct NativeEditorTextDelta: Equatable, Sendable {
    let replacedCharacterRange: Range<Int>
    let replacement: String

    var insertionCharacterOffset: Int {
        replacedCharacterRange.lowerBound + replacement.count
    }

    init(replacedCharacterRange: Range<Int>, replacement: String) {
        self.replacedCharacterRange = replacedCharacterRange
        self.replacement = replacement
    }

    init?(previousText: String, updatedText: String) {
        guard previousText != updatedText else { return nil }

        let previousCharacters = Array(previousText)
        let updatedCharacters = Array(updatedText)
        let sharedPrefixCount = Self.sharedPrefixCount(previousCharacters, updatedCharacters)
        let sharedSuffixCount = Self.sharedSuffixCount(
            previousCharacters,
            updatedCharacters,
            afterSharedPrefix: sharedPrefixCount
        )

        replacedCharacterRange = sharedPrefixCount..<(previousCharacters.count - sharedSuffixCount)
        replacement = String(
            updatedCharacters[sharedPrefixCount..<(updatedCharacters.count - sharedSuffixCount)]
        )
    }

    func applying(to source: AttributedString) -> AttributedString {
        let safeDelta = adjustedForAtomicInlineContent(in: source)
        var result = source
        let clampedRange = NativeEditorCharacterRange.clamped(
            safeDelta.replacedCharacterRange,
            count: source.characters.count
        )
        let attributedRange = NativeEditorCharacterRange.attributedRange(for: clampedRange, in: source)
        var replacementText = AttributedString(safeDelta.replacement)

        if replacementText.characters.isEmpty == false,
           var inheritedAttributes = Self.inheritedAttributes(
               at: attributedRange.lowerBound,
               replacedRange: attributedRange,
               in: source
           ) {
            inheritedAttributes[NativeEditorMentionAttribute.self] = nil
            inheritedAttributes[NativeEditorStatusAttribute.self] = nil
            inheritedAttributes[NativeEditorMathInlineAttribute.self] = nil
            replacementText.mergeAttributes(inheritedAttributes)
        }

        result.replaceSubrange(attributedRange, with: replacementText)
        return result
    }

    func adjustedForAtomicInlineContent(in source: AttributedString) -> NativeEditorTextDelta {
        let safeRange = NativeEditorAtomicTextRange.editingRange(
            for: replacedCharacterRange,
            in: source
        )
        guard safeRange != replacedCharacterRange else { return self }
        return NativeEditorTextDelta(replacedCharacterRange: safeRange, replacement: replacement)
    }

    func applying(to source: String) -> String {
        let range = NativeEditorCharacterRange.clamped(replacedCharacterRange, count: source.count)
        let lowerBound = source.index(source.startIndex, offsetBy: range.lowerBound)
        let upperBound = source.index(source.startIndex, offsetBy: range.upperBound)
        var result = source
        result.replaceSubrange(lowerBound..<upperBound, with: replacement)
        return result
    }

    private static func sharedPrefixCount(_ lhs: [Character], _ rhs: [Character]) -> Int {
        var count = 0
        while count < lhs.count, count < rhs.count, lhs[count] == rhs[count] {
            count += 1
        }
        return count
    }

    private static func sharedSuffixCount(
        _ lhs: [Character],
        _ rhs: [Character],
        afterSharedPrefix sharedPrefixCount: Int
    ) -> Int {
        let maximumSuffixCount = min(lhs.count, rhs.count) - sharedPrefixCount
        var count = 0
        while count < maximumSuffixCount,
              lhs[lhs.count - count - 1] == rhs[rhs.count - count - 1] {
            count += 1
        }
        return count
    }

    private static func inheritedAttributes(
        at insertionIndex: AttributedString.Index,
        replacedRange: Range<AttributedString.Index>,
        in source: AttributedString
    ) -> AttributeContainer? {
        if replacedRange.isEmpty == false, insertionIndex < source.endIndex {
            let attributes = source[
                insertionIndex..<source.characters.index(after: insertionIndex)
            ].runs.first?.attributes
            if attributes?.hasNativeEditorAtomicInlineAttribute == false {
                return attributes
            }
        }

        if insertionIndex > source.startIndex {
            let previousIndex = source.characters.index(before: insertionIndex)
            if let previousAttributes = source[previousIndex..<insertionIndex].runs.first?.attributes,
               previousAttributes.hasNativeEditorAtomicInlineAttribute == false {
                return previousAttributes
            }
        }

        let followingIndex = replacedRange.isEmpty ? insertionIndex : replacedRange.upperBound
        if followingIndex < source.endIndex {
            let nextIndex = source.characters.index(after: followingIndex)
            let followingAttributes = source[followingIndex..<nextIndex].runs.first?.attributes
            if followingAttributes?.hasNativeEditorAtomicInlineAttribute == false {
                return followingAttributes
            }
        }

        return nil
    }
}

nonisolated enum NativeEditorCharacterRange {
    static func clamped(_ range: Range<Int>, count: Int) -> Range<Int> {
        let lowerBound = min(max(range.lowerBound, 0), count)
        let upperBound = min(max(range.upperBound, lowerBound), count)
        return lowerBound..<upperBound
    }

    static func attributedRange(
        for characterRange: Range<Int>,
        in text: AttributedString
    ) -> Range<AttributedString.Index> {
        let range = clamped(characterRange, count: text.characters.count)
        let lowerBound = text.characters.index(text.startIndex, offsetBy: range.lowerBound)
        let upperBound = text.characters.index(text.startIndex, offsetBy: range.upperBound)
        return lowerBound..<upperBound
    }

    static func characterRange(
        for attributedSelection: AttributedTextSelection,
        in text: AttributedString
    ) -> Range<Int>? {
        switch attributedSelection.indices(in: text) {
        case .insertionPoint(let index):
            let offset = text.characters.distance(from: text.startIndex, to: index)
            return offset..<offset
        case .ranges(let ranges):
            guard let range = ranges.ranges.first else { return nil }
            let lowerBound = text.characters.distance(from: text.startIndex, to: range.lowerBound)
            let upperBound = text.characters.distance(from: text.startIndex, to: range.upperBound)
            return lowerBound..<upperBound
        }
    }

    static func attributedSelection(
        for characterRange: Range<Int>,
        in text: AttributedString
    ) -> AttributedTextSelection {
        let range = attributedRange(for: characterRange, in: text)
        if range.isEmpty {
            return AttributedTextSelection(insertionPoint: range.lowerBound)
        }
        return AttributedTextSelection(range: range)
    }

    static func characterRange(for nsRange: NSRange, in text: String) -> Range<Int>? {
        guard let stringRange = Range(nsRange, in: text) else { return nil }
        let lowerBound = text.distance(from: text.startIndex, to: stringRange.lowerBound)
        let upperBound = text.distance(from: text.startIndex, to: stringRange.upperBound)
        return lowerBound..<upperBound
    }

    static func nsRange(for characterRange: Range<Int>, in text: String) -> NSRange {
        let range = clamped(characterRange, count: text.count)
        let lowerBound = text.index(text.startIndex, offsetBy: range.lowerBound)
        let upperBound = text.index(text.startIndex, offsetBy: range.upperBound)
        return NSRange(lowerBound..<upperBound, in: text)
    }
}

nonisolated enum NativeEditorTextBlockMutation {
    static func updating(
        _ block: NativeEditorBlock,
        authoritativeText: AttributedString,
        characterSelection: Range<Int>
    ) -> NativeEditorBlock {
        var updatedBlock = block
        updatedBlock.text = authoritativeText
        updatedBlock.selection = NativeEditorCharacterRange.attributedSelection(
            for: characterSelection,
            in: authoritativeText
        )
        return updatedBlock
    }
}

nonisolated struct NativeEditorTextBindingEchoReconciler {
    enum Disposition: Equatable {
        case current
        case staleLocalEcho
        case external
    }

    private var pendingLocalTexts: [AttributedString] = []

    mutating func recordLocalTransition(
        from previousText: AttributedString,
        to updatedText: AttributedString
    ) {
        appendIfNeeded(previousText)
        appendIfNeeded(updatedText)
        if pendingLocalTexts.count > 64 {
            pendingLocalTexts.removeFirst(pendingLocalTexts.count - 64)
        }
    }

    mutating func disposition(
        for boundText: AttributedString,
        authoritativeText: AttributedString
    ) -> Disposition {
        if boundText == authoritativeText {
            pendingLocalTexts.removeAll()
            return .current
        }
        if let echoIndex = pendingLocalTexts.firstIndex(of: boundText) {
            pendingLocalTexts.removeFirst(echoIndex + 1)
            return .staleLocalEcho
        }

        pendingLocalTexts.removeAll()
        return .external
    }

    mutating func reset() {
        pendingLocalTexts.removeAll()
    }

    private mutating func appendIfNeeded(_ text: AttributedString) {
        guard pendingLocalTexts.last != text else { return }
        pendingLocalTexts.append(text)
    }
}

nonisolated struct NativeEditorFocusBindingEchoReconciler {
    enum Disposition: Equatable {
        case activate
        case preserveLocalActivation
        case deactivate
    }

    private var isAwaitingLocalActivationEcho = false

    mutating func recordLocalActivation() {
        isAwaitingLocalActivationEcho = true
    }

    mutating func recordLocalDeactivation() {
        isAwaitingLocalActivationEcho = false
    }

    mutating func disposition(
        for boundIsFocused: Bool,
        platformIsFocused: Bool
    ) -> Disposition {
        if boundIsFocused {
            isAwaitingLocalActivationEcho = false
            return .activate
        }

        if isAwaitingLocalActivationEcho, platformIsFocused {
            return .preserveLocalActivation
        }

        isAwaitingLocalActivationEcho = false
        return .deactivate
    }
}

nonisolated enum NativeEditorAtomicTextRange {
    static func selectionRange(for requestedRange: Range<Int>, in text: AttributedString) -> Range<Int> {
        let clampedRange = NativeEditorCharacterRange.clamped(requestedRange, count: text.characters.count)
        let atomicRanges = ranges(in: text)

        if clampedRange.isEmpty {
            guard let atomicRange = atomicRanges.first(where: {
                clampedRange.lowerBound > $0.lowerBound && clampedRange.lowerBound < $0.upperBound
            }) else {
                return clampedRange
            }

            let distanceToStart = clampedRange.lowerBound - atomicRange.lowerBound
            let distanceToEnd = atomicRange.upperBound - clampedRange.lowerBound
            let insertionOffset = distanceToStart <= distanceToEnd ? atomicRange.lowerBound : atomicRange.upperBound
            return insertionOffset..<insertionOffset
        }

        return atomicRanges.reduce(clampedRange) { range, atomicRange in
            guard range.overlaps(atomicRange) else { return range }
            return min(range.lowerBound, atomicRange.lowerBound)..<max(range.upperBound, atomicRange.upperBound)
        }
    }

    static func editingRange(for requestedRange: Range<Int>, in text: AttributedString) -> Range<Int> {
        selectionRange(for: requestedRange, in: text)
    }

    private static func ranges(in text: AttributedString) -> [Range<Int>] {
        text.runs.compactMap { run in
            guard run.attributes.hasNativeEditorAtomicInlineAttribute else { return nil }
            let lowerBound = text.characters.distance(from: text.startIndex, to: run.range.lowerBound)
            let upperBound = text.characters.distance(from: text.startIndex, to: run.range.upperBound)
            return lowerBound..<upperBound
        }
    }
}

nonisolated extension AttributeContainer {
    var hasNativeEditorAtomicInlineAttribute: Bool {
        self[NativeEditorMentionAttribute.self] != nil ||
            self[NativeEditorStatusAttribute.self] != nil ||
            self[NativeEditorMathInlineAttribute.self] != nil
    }
}

nonisolated extension AttributedString {
    var nativeEditorPlatformRenderableText: AttributedString {
        var renderedText = self
        let fullRange = renderedText.startIndex..<renderedText.endIndex
        renderedText[fullRange][NativeEditorHighlightColorAttribute.self] = nil
        renderedText[fullRange][NativeEditorHighlightColorNameAttribute.self] = nil
        renderedText[fullRange][NativeEditorTextColorAttribute.self] = nil
        renderedText[fullRange][NativeEditorLinkAttribute.self] = nil
        renderedText[fullRange][NativeEditorCommentIDAttribute.self] = nil
        renderedText[fullRange][NativeEditorCommentResolvedAttribute.self] = nil
        renderedText[fullRange][NativeEditorCommentMarksAttribute.self] = nil
        renderedText[fullRange][NativeEditorMentionAttribute.self] = nil
        renderedText[fullRange][NativeEditorStatusAttribute.self] = nil
        renderedText[fullRange][NativeEditorMathInlineAttribute.self] = nil
        return renderedText
    }
}
