import Foundation
import SwiftUI
import Testing
@testable import docmostly

struct NativeEditorTextMutationTests {
    @Test func infersUnicodeSafeReplacementInCharacterOffsets() throws {
        let delta = try #require(
            NativeEditorTextDelta(previousText: "A👩‍🚀B", updatedText: "A👩‍🚀 bright B")
        )

        #expect(delta.replacedCharacterRange == 2..<2)
        #expect(delta.replacement == " bright ")
        #expect(delta.insertionCharacterOffset == 10)
    }

    @Test func explicitDeltaPreservesSemanticRunsOutsideEdit() throws {
        var text = AttributedString("Mention plain status math link highlighted")
        let mentionRange = try attributedRange(of: "Mention", in: text)
        let statusRange = try attributedRange(of: "status", in: text)
        let mathRange = try attributedRange(of: "math", in: text)
        let linkRange = try attributedRange(of: "link", in: text)
        let highlightRange = try attributedRange(of: "highlighted", in: text)

        let mention = NativeEditorMention(
            identifier: "mention-1",
            label: "Mention",
            entityType: "user",
            entityID: "user-1",
            slugID: nil,
            creatorID: nil,
            anchorID: nil
        )
        text[mentionRange][NativeEditorMentionAttribute.self] = mention
        text[statusRange][NativeEditorStatusAttribute.self] = NativeEditorStatusBadge(text: "status", color: "green")
        text[mathRange][NativeEditorMathInlineAttribute.self] = NativeEditorMathInline(text: "x^2")
        text[linkRange][NativeEditorLinkAttribute.self] = NativeEditorLink(href: "/s/test/p/page", isInternal: true)
        text[linkRange].link = URL(string: "https://example.com/s/test/p/page")
        text[highlightRange][NativeEditorHighlightColorNameAttribute.self] = "yellow"
        text[highlightRange].backgroundColor = .yellow
        text[highlightRange].setNativeEditorInlineComments([
            NativeEditorInlineCommentMark(commentID: "comment-1", isResolved: false)
        ])

        let plainText = String(text.characters)
        let editIndex = try #require(plainText.range(of: "plain")?.lowerBound)
        let characterOffset = plainText.distance(from: plainText.startIndex, to: editIndex)
        let updated = NativeEditorTextDelta(
            replacedCharacterRange: characterOffset..<(characterOffset + 5),
            replacement: "ordinary"
        ).applying(to: text)

        #expect(String(updated.characters) == "Mention ordinary status math link highlighted")
        #expect(try attributes(for: "Mention", in: updated)[NativeEditorMentionAttribute.self] == mention)
        #expect(try attributes(for: "status", in: updated)[NativeEditorStatusAttribute.self]?.color == "green")
        #expect(try attributes(for: "math", in: updated)[NativeEditorMathInlineAttribute.self]?.text == "x^2")
        #expect(try attributes(for: "link", in: updated)[NativeEditorLinkAttribute.self]?.isInternal == true)
        #expect(
            try attributes(for: "highlighted", in: updated)[NativeEditorHighlightColorNameAttribute.self] == "yellow"
        )
        #expect(
            try attributes(for: "highlighted", in: updated)
                .nativeEditorInlineComments
                .first?
                .commentID == "comment-1"
        )
    }

    @Test func insertedTextInheritsMarksWithoutExtendingAtomicInlineAttributes() throws {
        var text = AttributedString("Bold Mention")
        let boldRange = try attributedRange(of: "Bold", in: text)
        text[boldRange].inlinePresentationIntent = .stronglyEmphasized

        let mentionRange = try attributedRange(of: "Mention", in: text)
        text[mentionRange][NativeEditorMentionAttribute.self] = NativeEditorMention(
            identifier: "mention-1",
            label: "Mention",
            entityType: "user",
            entityID: "user-1",
            slugID: nil,
            creatorID: nil,
            anchorID: nil
        )

        let boldInsertion = NativeEditorTextDelta(replacedCharacterRange: 2..<2, replacement: "!").applying(to: text)
        #expect(try attributes(for: "!", in: boldInsertion).inlinePresentationIntent == .stronglyEmphasized)

        let mentionInsertion = NativeEditorTextDelta(
            replacedCharacterRange: text.characters.count..<text.characters.count,
            replacement: "!"
        ).applying(to: text)
        #expect(try attributes(for: "!", in: mentionInsertion)[NativeEditorMentionAttribute.self] == nil)
    }

    @Test func explicitTypingMarksOnlyApplyToInsertedText() throws {
        let text = AttributedString("Plain")
        let updated = NativeEditorTextDelta(
            replacedCharacterRange: text.characters.count..<text.characters.count,
            replacement: " styled"
        ).applying(to: text, typingInlineMarks: [.bold, .italic, .code])

        let existingAttributes = try attributes(for: "Plain", in: updated)
        let insertedAttributes = try attributes(for: "styled", in: updated)
        #expect(existingAttributes.inlinePresentationIntent == nil)
        #expect(insertedAttributes.inlinePresentationIntent?.contains(.stronglyEmphasized) == true)
        #expect(insertedAttributes.inlinePresentationIntent?.contains(.emphasized) == true)
        #expect(insertedAttributes.inlinePresentationIntent?.contains(.code) == true)
    }

    @Test func explicitEmptyTypingMarksCanEndInheritedFormatting() throws {
        var text = AttributedString("Bold")
        text.inlinePresentationIntent = .stronglyEmphasized
        let updated = NativeEditorTextDelta(
            replacedCharacterRange: text.characters.count..<text.characters.count,
            replacement: " plain"
        ).applying(to: text, typingInlineMarks: [])

        #expect(try attributes(for: "Bold", in: updated).inlinePresentationIntent == .stronglyEmphasized)
        #expect(try attributes(for: "plain", in: updated).inlinePresentationIntent == nil)
    }

    @Test func insertedTextPreservesLinkHighlightAndCommentMarks() throws {
        var text = AttributedString("linked")
        let fullRange = text.startIndex..<text.endIndex
        text[fullRange][NativeEditorLinkAttribute.self] = NativeEditorLink(
            href: "/s/test/p/page",
            isInternal: true
        )
        text[fullRange][NativeEditorHighlightColorNameAttribute.self] = "yellow"
        text[fullRange].setNativeEditorInlineComments([
            NativeEditorInlineCommentMark(commentID: "comment-1", isResolved: false)
        ])

        let updated = NativeEditorTextDelta(
            replacedCharacterRange: 3..<3,
            replacement: "!"
        ).applying(to: text)
        let insertedAttributes = try attributes(for: "!", in: updated)

        #expect(insertedAttributes[NativeEditorLinkAttribute.self]?.isInternal == true)
        #expect(insertedAttributes[NativeEditorHighlightColorNameAttribute.self] == "yellow")
        #expect(insertedAttributes.nativeEditorInlineComments.first?.commentID == "comment-1")
    }

    @Test func explicitDeltaKeepsExactLocationInRepeatedText() {
        let delta = NativeEditorTextDelta(replacedCharacterRange: 0..<0, replacement: "a")

        #expect(delta.applying(to: "aaa") == "aaaa")
        #expect(delta.replacedCharacterRange == 0..<0)
    }

    @Test func rapidLocalBindingEchoesCannotRollBackAuthoritativeText() {
        var reconciler = NativeEditorTextBindingEchoReconciler()
        var authoritativeText = AttributedString("")

        for updatedValue in ["A", "AB", "ABC", "ABCD", "ABCDE"] {
            let updatedText = AttributedString(updatedValue)
            reconciler.recordLocalTransition(from: authoritativeText, to: updatedText)
            authoritativeText = updatedText
        }

        for staleValue in ["", "A", "AB", "ABC", "ABCD"] {
            #expect(
                reconciler.disposition(
                    for: AttributedString(staleValue),
                    authoritativeText: authoritativeText
                ) == .staleLocalEcho
            )
        }
        #expect(
            reconciler.disposition(
                for: AttributedString("ABCDE"),
                authoritativeText: authoritativeText
            ) == .current
        )
        #expect(
            reconciler.disposition(
                for: AttributedString("Server replacement"),
                authoritativeText: authoritativeText
            ) == .external
        )
    }

    @Test func wholeBlockCommitOverridesStaleBindingSnapshotDuringRapidTyping() throws {
        let staleBindingBlock = NativeEditorBlock(
            kind: .heading(level: 2),
            text: AttributedString("A"),
            alignment: .right,
            indentLevel: 2
        )
        var committedBlock = staleBindingBlock

        for updatedValue in ["AB", "ABC", "ABCD", "ABCDE"] {
            let authoritativeText = AttributedString(updatedValue)
            let insertionOffset = authoritativeText.characters.count
            committedBlock = NativeEditorTextBlockMutation.updating(
                staleBindingBlock,
                authoritativeText: authoritativeText,
                characterSelection: insertionOffset..<insertionOffset
            )
        }

        #expect(String(committedBlock.text.characters) == "ABCDE")
        #expect(committedBlock.kind == .heading(level: 2))
        #expect(committedBlock.alignment == .right)
        #expect(committedBlock.indentLevel == 2)
        #expect(try insertionOffset(in: committedBlock) == 5)
    }

    @Test func staleFocusBindingEchoCannotInterruptLocalTypingSession() {
        var reconciler = NativeEditorFocusBindingEchoReconciler()

        reconciler.recordLocalActivation()

        #expect(
            reconciler.disposition(
                for: false,
                platformIsFocused: true
            ) == .preserveLocalActivation
        )
        #expect(
            reconciler.disposition(
                for: false,
                platformIsFocused: true
            ) == .preserveLocalActivation
        )
        #expect(
            reconciler.disposition(
                for: true,
                platformIsFocused: true
            ) == .activate
        )
        #expect(
            reconciler.disposition(
                for: false,
                platformIsFocused: true
            ) == .deactivate
        )
    }

    @Test func nativeFocusLossCancelsPendingActivationEcho() {
        var reconciler = NativeEditorFocusBindingEchoReconciler()

        reconciler.recordLocalActivation()
        reconciler.recordLocalDeactivation()

        #expect(
            reconciler.disposition(
                for: false,
                platformIsFocused: false
            ) == .deactivate
        )
    }

    @Test func activeBlockHandoffPreservesPreviousInputUntilContinuationActivates() {
        var previousBlockReconciler = NativeEditorFocusBindingEchoReconciler()
        var continuationBlockReconciler = NativeEditorFocusBindingEchoReconciler()

        #expect(
            previousBlockReconciler.disposition(
                for: false,
                platformIsFocused: true,
                preservesPlatformFocusDuringHandoff: true
            ) == .preserveDuringHandoff
        )
        #expect(
            continuationBlockReconciler.disposition(
                for: true,
                platformIsFocused: false
            ) == .activate
        )
        #expect(
            previousBlockReconciler.disposition(
                for: false,
                platformIsFocused: false,
                preservesPlatformFocusDuringHandoff: true
            ) == .deactivate
        )
    }

    @Test func partialAtomicInlineEditsRemoveWholeAtomWithoutTouchingNeighbors() throws {
        let atomicText = try textWithAtomicInlineRuns()

        let mentionEdit = NativeEditorTextDelta(
            replacedCharacterRange: 2..<3,
            replacement: ""
        ).applying(to: atomicText)
        #expect(String(mentionEdit.characters) == " status math")
        #expect(mentionEdit.runs.contains { $0[NativeEditorMentionAttribute.self] != nil } == false)
        #expect(mentionEdit.runs.contains { $0[NativeEditorStatusAttribute.self] != nil })
        #expect(mentionEdit.runs.contains { $0[NativeEditorMathInlineAttribute.self] != nil })

        let statusEdit = NativeEditorTextDelta(
            replacedCharacterRange: 9..<10,
            replacement: "ready"
        ).applying(to: atomicText)
        #expect(String(statusEdit.characters) == "Mention ready math")
        #expect(statusEdit.runs.contains { $0[NativeEditorMentionAttribute.self] != nil })
        #expect(statusEdit.runs.contains { $0[NativeEditorStatusAttribute.self] != nil } == false)
        #expect(statusEdit.runs.contains { $0[NativeEditorMathInlineAttribute.self] != nil })

        let mathEdit = NativeEditorTextDelta(
            replacedCharacterRange: 16..<17,
            replacement: ""
        ).applying(to: atomicText)
        #expect(String(mathEdit.characters) == "Mention status ")
        #expect(mathEdit.runs.contains { $0[NativeEditorMentionAttribute.self] != nil })
        #expect(mathEdit.runs.contains { $0[NativeEditorStatusAttribute.self] != nil })
        #expect(mathEdit.runs.contains { $0[NativeEditorMathInlineAttribute.self] != nil } == false)
    }

    @Test func caretInsideAtomicInlineSnapsToNearestBoundary() throws {
        let atomicText = try textWithAtomicInlineRuns()

        #expect(NativeEditorAtomicTextRange.selectionRange(for: 2..<2, in: atomicText) == 0..<0)
        #expect(NativeEditorAtomicTextRange.selectionRange(for: 6..<6, in: atomicText) == 7..<7)

        let insertion = NativeEditorTextDelta(
            replacedCharacterRange: 6..<6,
            replacement: "!"
        ).applying(to: atomicText)
        #expect(String(insertion.characters) == "Mention! status math")
        #expect(try attributes(for: "Mention", in: insertion)[NativeEditorMentionAttribute.self] != nil)
        #expect(try attributes(for: "!", in: insertion)[NativeEditorMentionAttribute.self] == nil)
    }

    @Test func platformRenderingCopyDropsOnlyNonBridgeableSemanticMetadata() throws {
        let source = try textWithAtomicInlineRuns()
        let rendered = source.nativeEditorPlatformRenderableText

        #expect(source.runs.contains { $0[NativeEditorMentionAttribute.self] != nil })
        #expect(source.runs.contains { $0[NativeEditorStatusAttribute.self] != nil })
        #expect(source.runs.contains { $0[NativeEditorMathInlineAttribute.self] != nil })
        #expect(rendered.runs.contains { $0[NativeEditorMentionAttribute.self] != nil } == false)
        #expect(rendered.runs.contains { $0[NativeEditorStatusAttribute.self] != nil } == false)
        #expect(rendered.runs.contains { $0[NativeEditorMathInlineAttribute.self] != nil } == false)
        #expect(String(rendered.characters) == String(source.characters))
    }

    @Test func codeBlockReturnUsesLineBreakUntilThirdTrailingReturn() {
        let codeKind = NativeEditorBlockKind.codeBlock(language: "swift")

        #expect(
            NativeEditorReturnKeyBehavior.resolve(
                kind: codeKind,
                text: AttributedString("let value = 1"),
                selection: 13..<13
            ) == .insertHardBreak
        )
        #expect(
            NativeEditorReturnKeyBehavior.resolve(
                kind: codeKind,
                text: AttributedString("let value = 1\n\n"),
                selection: 15..<15
            ) == .splitBlock
        )
        #expect(
            NativeEditorReturnKeyBehavior.resolve(
                kind: .paragraph,
                text: AttributedString("Body"),
                selection: 4..<4
            ) == .splitBlock
        )
    }

    @Test func convertsBetweenAttributedCharacterAndUTF16Ranges() {
        let value = "A👩‍🚀🇮🇪B"
        let characterRange = 1..<3
        let nsRange = NativeEditorCharacterRange.nsRange(for: characterRange, in: value)

        #expect(nsRange.length > characterRange.count)
        #expect(NativeEditorCharacterRange.characterRange(for: nsRange, in: value) == characterRange)
    }

    private func attributedRange(
        of substring: String,
        in text: AttributedString
    ) throws -> Range<AttributedString.Index> {
        try #require(text.range(of: substring))
    }

    private func attributes(
        for substring: String,
        in text: AttributedString
    ) throws -> AttributeContainer {
        let range = try attributedRange(of: substring, in: text)
        return try #require(text[range].runs.first?.attributes)
    }

    private func insertionOffset(in block: NativeEditorBlock) throws -> Int {
        switch block.selection.indices(in: block.text) {
        case .insertionPoint(let index):
            return block.text.characters.distance(from: block.text.startIndex, to: index)
        case .ranges:
            Issue.record("Expected an insertion-point selection")
            return -1
        }
    }

    private func textWithAtomicInlineRuns() throws -> AttributedString {
        var text = AttributedString("Mention status math")
        let mentionRange = try attributedRange(of: "Mention", in: text)
        let statusRange = try attributedRange(of: "status", in: text)
        let mathRange = try attributedRange(of: "math", in: text)

        text[mentionRange][NativeEditorMentionAttribute.self] = NativeEditorMention(
            identifier: "mention-1",
            label: "Mention",
            entityType: "user",
            entityID: "user-1",
            slugID: nil,
            creatorID: nil,
            anchorID: nil
        )
        text[statusRange][NativeEditorStatusAttribute.self] = NativeEditorStatusBadge(text: "status", color: "green")
        text[mathRange][NativeEditorMathInlineAttribute.self] = NativeEditorMathInline(text: "x^2")
        return text
    }
}
