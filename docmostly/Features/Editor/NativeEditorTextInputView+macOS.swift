#if os(macOS)
import AppKit
import SwiftUI

struct NativeEditorTextInputView: NSViewRepresentable {
    @Binding var block: NativeEditorBlock

    let isEditable: Bool
    let isFocused: Bool
    let focusRequestID: UUID?
    let retainsResponderDuringFocusHandoff: Bool
    let focusChanged: (Bool) -> Void
    let typingInlineMarks: Set<NativeEditorInlineMark>
    let invalidateTypingContext: () -> Void
    let accessibilityLabel: String
    let actions: NativeEditorTextInputActions
    var remotePresenceSegments: [NativeEditorRemotePresenceSegment] = []

    func makeCoordinator() -> NativeEditorTextInputCoordinator {
        NativeEditorTextInputCoordinator(parent: self)
    }

    func makeNSView(context: Context) -> NativeEditorNSTextView {
        let textView = NativeEditorNSTextView(frame: .zero)
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.isRichText = true
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainerInset = .zero
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.setAccessibilityLabel(accessibilityLabel)
        context.coordinator.applySource(to: textView)
        context.coordinator.configure(textView)
        context.coordinator.updateFocus(textView)
        textView.updateRemotePresence(remotePresenceSegments)
        return textView
    }

    func updateNSView(_ textView: NativeEditorNSTextView, context: Context) {
        context.coordinator.parent = self
        textView.isEditable = isEditable
        context.coordinator.updateFromBoundBlock(textView)
        context.coordinator.configure(textView)
        context.coordinator.updateFocus(textView)
        textView.updateRemotePresence(remotePresenceSegments)
    }

    static func dismantleNSView(
        _ textView: NativeEditorNSTextView,
        coordinator: NativeEditorTextInputCoordinator
    ) {
        textView.requestsFirstResponder = false
        if textView.window?.firstResponder === textView {
            textView.window?.makeFirstResponder(nil)
        }
        coordinator.parent.focusChanged(false)
        textView.delegate = nil
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        nsView: NativeEditorNSTextView,
        context: Context
    ) -> CGSize? {
        guard
            let width = proposal.width,
            width.isFinite,
            width > 0,
            let textContainer = nsView.textContainer,
            let layoutManager = nsView.layoutManager
        else {
            return nil
        }

        textContainer.containerSize = CGSize(width: width, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: textContainer)
        let usedHeight = layoutManager.usedRect(for: textContainer).height
        let lineHeight = nsView.font?.boundingRectForFont.height ?? 0
        return CGSize(width: width, height: ceil(max(usedHeight, lineHeight)))
    }
}

@MainActor
final class NativeEditorTextInputCoordinator: NSObject, NSTextViewDelegate {
    var parent: NativeEditorTextInputView
    private(set) var sourceText: AttributedString

    private var renderedPlainText: String
    private var isApplyingSource = false
    private var pendingTextDelta: NativeEditorTextDelta?
    private var textDrivenSelection: Range<Int>?
    private var pendingSelectionCorrection: Range<Int>?
    private var handledFocusRequestID: UUID?
    private var bindingEchoReconciler = NativeEditorTextBindingEchoReconciler()
    private var focusBindingEchoReconciler = NativeEditorFocusBindingEchoReconciler()

    init(parent: NativeEditorTextInputView) {
        self.parent = parent
        sourceText = parent.block.text
        renderedPlainText = String(parent.block.text.characters)
        super.init()
    }

    // AppKit resets typing attributes when the selection changes, so call this
    // after synchronizing both the text storage and selection.
    func configure(_ textView: NSTextView) {
        let font = platformFont(for: parent.block.kind)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = platformAlignment(parent.block.alignment)

        textView.font = font
        textView.alignment = paragraphStyle.alignment
        textView.defaultParagraphStyle = paragraphStyle
        textView.typingAttributes = NativeEditorPlatformTypingAttributes.attributes(
            baseFont: font,
            marks: parent.typingInlineMarks,
            kind: parent.block.kind,
            paragraphStyle: paragraphStyle
        )
        textView.setAccessibilityLabel(parent.accessibilityLabel)
    }

    func updateFromBoundBlock(_ textView: NSTextView) {
        let boundText = parent.block.text
        if textView.hasMarkedText(), boundText != sourceText {
            return
        }

        switch bindingEchoReconciler.disposition(
            for: boundText,
            authoritativeText: sourceText
        ) {
        case .current:
            applyBoundSelectionIfNeeded(to: textView)
        case .staleLocalEcho:
            return
        case .external:
            applySource(to: textView)
        }
    }

    func applySource(to textView: NSTextView) {
        isApplyingSource = true
        defer { isApplyingSource = false }

        sourceText = parent.block.text
        bindingEchoReconciler.reset()
        renderedPlainText = String(sourceText.characters)
        textView.textStorage?.setAttributedString(
            renderedText(
                sourceText,
                font: platformFont(for: parent.block.kind),
                kind: parent.block.kind,
                alignment: platformAlignment(parent.block.alignment)
            )
        )
        (textView as? NativeEditorNSTextView)?.invalidateRemotePresenceRendering()
        applyBoundSelectionIfNeeded(to: textView)
    }

    func applyBoundSelectionIfNeeded(to textView: NSTextView) {
        guard
            let requestedRange = NativeEditorCharacterRange.characterRange(
                for: parent.block.selection,
                in: parent.block.text
            )
        else {
            return
        }

        let safeRange = NativeEditorAtomicTextRange.selectionRange(
            for: requestedRange,
            in: parent.block.text
        )
        let requestedSelection = NativeEditorCharacterRange.nsRange(
            for: safeRange,
            in: textView.string
        )
        if safeRange != requestedRange {
            scheduleBoundSelectionCorrection(safeRange)
        }
        guard textView.selectedRange() != requestedSelection else { return }

        isApplyingSource = true
        textView.setSelectedRange(requestedSelection)
        isApplyingSource = false
    }

    func textDidChange(_ notification: Notification) {
        guard
            isApplyingSource == false,
            let textView = notification.object as? NSTextView
        else {
            return
        }

        let updatedPlainText = textView.string
        guard let delta = resolvedTextDelta(for: updatedPlainText) else {
            synchronizeSelection(from: textView)
            return
        }

        let safeDelta = delta.adjustedForAtomicInlineContent(in: sourceText)
        let updatedSource = safeDelta.applying(to: sourceText, typingInlineMarks: parent.typingInlineMarks)
        let updatedSourcePlainText = String(updatedSource.characters)
        let insertionOffset = min(safeDelta.insertionCharacterOffset, updatedSource.characters.count)
        textDrivenSelection = insertionOffset..<insertionOffset
        bindingEchoReconciler.recordLocalTransition(from: sourceText, to: updatedSource)
        sourceText = updatedSource

        if updatedSourcePlainText == updatedPlainText {
            renderedPlainText = updatedPlainText
            synchronizeSelection(from: textView)
        } else {
            let insertionRange = insertionOffset..<insertionOffset
            parent.block = NativeEditorTextBlockMutation.updating(
                parent.block,
                authoritativeText: updatedSource,
                characterSelection: insertionRange
            )
            reconcilePlatformText(
                updatedSource,
                selection: insertionRange,
                in: textView
            )
        }
        textView.invalidateIntrinsicContentSize()
    }

    func textView(
        _ textView: NSTextView,
        shouldChangeTextIn affectedCharRange: NSRange,
        replacementString: String?
    ) -> Bool {
        guard
            isApplyingSource == false,
            let replacementString,
            let characterRange = NativeEditorCharacterRange.characterRange(
                for: affectedCharRange,
                in: textView.string
            )
        else {
            return true
        }

        pendingTextDelta = NativeEditorTextDelta(
            replacedCharacterRange: characterRange,
            replacement: replacementString
        )
        let insertionOffset = characterRange.lowerBound + replacementString.count
        textDrivenSelection = insertionOffset..<insertionOffset
        return true
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        guard
            isApplyingSource == false,
            let textView = notification.object as? NSTextView,
            textView.string == renderedPlainText
        else {
            return
        }
        let currentSelection = selectedCharacterRange(in: textView)
        if currentSelection != textDrivenSelection {
            parent.invalidateTypingContext()
            textDrivenSelection = nil
        }
        synchronizeSelection(from: textView)
    }

    func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard textView.hasMarkedText() == false else { return false }

        switch NSStringFromSelector(commandSelector) {
        case "insertLineBreak:":
            return performHardBreak(in: textView)
        case "insertNewline:", "insertNewlineIgnoringFieldEditor:":
            if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                return performHardBreak(in: textView)
            }
            guard let range = selectedCharacterRange(in: textView) else { return false }
            return parent.actions.handleReturn(range)
        case "deleteBackward:":
            guard
                textView.selectedRange().location == 0,
                textView.selectedRange().length == 0
            else {
                return false
            }
            return parent.actions.mergeBlockBackward()
        default:
            return false
        }
    }

    private func performHardBreak(in textView: NSTextView) -> Bool {
        guard let range = selectedCharacterRange(in: textView) else { return false }
        return parent.actions.insertHardBreak(range)
    }

    private func synchronizeSelection(from textView: NSTextView) {
        pendingSelectionCorrection = nil
        guard
            let requestedRange = NativeEditorCharacterRange.characterRange(
                for: textView.selectedRange(),
                in: textView.string
            )
        else {
            return
        }

        let safeRange = NativeEditorAtomicTextRange.selectionRange(for: requestedRange, in: sourceText)
        if safeRange != requestedRange {
            isApplyingSource = true
            textView.setSelectedRange(
                NativeEditorCharacterRange.nsRange(for: safeRange, in: textView.string)
            )
            isApplyingSource = false
        }

        let currentRange = NativeEditorCharacterRange.characterRange(
            for: parent.block.selection,
            in: parent.block.text
        )
        guard currentRange != safeRange || parent.block.text != sourceText else { return }
        parent.block = NativeEditorTextBlockMutation.updating(
            parent.block,
            authoritativeText: sourceText,
            characterSelection: safeRange
        )
    }

    private func selectedCharacterRange(in textView: NSTextView) -> Range<Int>? {
        guard let range = NativeEditorCharacterRange.characterRange(
            for: textView.selectedRange(),
            in: textView.string
        ) else {
            return nil
        }
        return NativeEditorAtomicTextRange.selectionRange(for: range, in: sourceText)
    }

    private func reconcilePlatformText(
        _ source: AttributedString,
        selection: Range<Int>,
        in textView: NSTextView
    ) {
        isApplyingSource = true
        defer { isApplyingSource = false }

        renderedPlainText = String(source.characters)
        textView.textStorage?.setAttributedString(
            renderedText(
                source,
                font: platformFont(for: parent.block.kind),
                kind: parent.block.kind,
                alignment: platformAlignment(parent.block.alignment)
            )
        )
        (textView as? NativeEditorNSTextView)?.invalidateRemotePresenceRendering()
        textView.setSelectedRange(
            NativeEditorCharacterRange.nsRange(for: selection, in: renderedPlainText)
        )
        pendingTextDelta = nil
    }

    private func resolvedTextDelta(for updatedPlainText: String) -> NativeEditorTextDelta? {
        defer { pendingTextDelta = nil }
        if let pendingTextDelta,
           pendingTextDelta.applying(to: renderedPlainText) == updatedPlainText {
            return pendingTextDelta
        }
        return NativeEditorTextDelta(
            previousText: renderedPlainText,
            updatedText: updatedPlainText
        )
    }

    private func scheduleBoundSelectionCorrection(_ safeRange: Range<Int>) {
        guard pendingSelectionCorrection != safeRange else { return }
        pendingSelectionCorrection = safeRange
        Task { @MainActor [weak self] in
            await Task.yield()
            guard let self, pendingSelectionCorrection == safeRange else { return }
            defer {
                if pendingSelectionCorrection == safeRange {
                    pendingSelectionCorrection = nil
                }
            }
            let currentRange = NativeEditorCharacterRange.characterRange(
                for: parent.block.selection,
                in: parent.block.text
            ) ?? safeRange
            guard NativeEditorAtomicTextRange.selectionRange(
                for: currentRange,
                in: parent.block.text
            ) == safeRange else {
                return
            }
            parent.block = NativeEditorTextBlockMutation.updating(
                parent.block,
                authoritativeText: sourceText,
                characterSelection: safeRange
            )
        }
    }

    private func renderedText(
        _ text: AttributedString,
        font: NSFont,
        kind: NativeEditorBlockKind,
        alignment: NSTextAlignment
    ) -> NSAttributedString {
        let rendered = NSMutableAttributedString(
            attributedString: NSAttributedString(text.nativeEditorPlatformRenderableText)
        )
        let fullRange = NSRange(location: 0, length: rendered.length)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment

        rendered.addAttribute(.font, value: font, range: fullRange)
        applyInlinePresentationFonts(from: text, baseFont: font, kind: kind, to: rendered)
        var rangesMissingForegroundColor: [NSRange] = []
        rendered.enumerateAttribute(.foregroundColor, in: fullRange) { value, range, _ in
            if value == nil {
                rangesMissingForegroundColor.append(range)
            }
        }
        for range in rangesMissingForegroundColor {
            rendered.addAttribute(.foregroundColor, value: NSColor.labelColor, range: range)
        }
        rendered.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        return rendered
    }

    private func applyInlinePresentationFonts(
        from text: AttributedString,
        baseFont: NSFont,
        kind: NativeEditorBlockKind,
        to rendered: NSMutableAttributedString
    ) {
        let plainText = String(text.characters)
        for run in text.runs {
            guard let intent = run.inlinePresentationIntent else { continue }
            let lowerBound = text.characters.distance(from: text.startIndex, to: run.range.lowerBound)
            let upperBound = text.characters.distance(from: text.startIndex, to: run.range.upperBound)
            let characterRange = lowerBound..<upperBound
            let range = NativeEditorCharacterRange.nsRange(for: characterRange, in: plainText)
            let hasStrongEmphasis = intent.contains(.stronglyEmphasized)
            let usesHeavyHeadingWeight = hasStrongEmphasis && kind.isHeading
            let emphasizedWeight: NSFont.Weight = usesHeavyHeadingWeight ? .heavy : .regular
            var runFont: NSFont
            if intent.contains(.code) {
                runFont = NSFont.monospacedSystemFont(
                    ofSize: baseFont.pointSize,
                    weight: emphasizedWeight
                )
            } else if usesHeavyHeadingWeight {
                runFont = NSFont.systemFont(ofSize: baseFont.pointSize, weight: emphasizedWeight)
            } else {
                runFont = baseFont
            }
            if hasStrongEmphasis && usesHeavyHeadingWeight == false {
                runFont = NSFontManager.shared.convert(runFont, toHaveTrait: .boldFontMask)
            }
            if intent.contains(.emphasized) {
                runFont = NSFontManager.shared.convert(runFont, toHaveTrait: .italicFontMask)
            }
            rendered.addAttribute(.font, value: runFont, range: range)
            if intent.contains(.strikethrough) {
                rendered.addAttribute(
                    .strikethroughStyle,
                    value: NSUnderlineStyle.single.rawValue,
                    range: range
                )
            }
        }
    }

    private func platformFont(for kind: NativeEditorBlockKind) -> NSFont {
        switch kind {
        case .heading:
            let font = NSFont.preferredFont(
                forTextStyle: kind.headingTextStyle,
                options: [:]
            )
            return NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        case .codeBlock:
            let bodyFont = NSFont.preferredFont(forTextStyle: .body, options: [:])
            return NSFont.monospacedSystemFont(ofSize: bodyFont.pointSize, weight: .regular)
        default:
            return NSFont.preferredFont(forTextStyle: .body, options: [:])
        }
    }

    private func platformAlignment(_ alignment: NativeEditorTextAlignment) -> NSTextAlignment {
        switch alignment {
        case .left:
            .natural
        case .center:
            .center
        case .right:
            .right
        case .justify:
            .justified
        }
    }
}

extension NativeEditorTextInputCoordinator {
    func updateFocus(_ textView: NativeEditorNSTextView) {
        guard parent.isEditable else {
            textView.requestsFirstResponder = false
            guard textView.window?.firstResponder === textView else { return }
            textView.window?.makeFirstResponder(nil)
            return
        }

        if let focusRequestID = parent.focusRequestID,
           focusRequestID != handledFocusRequestID,
           parent.isFocused {
            handledFocusRequestID = focusRequestID
            textView.requestsFirstResponder = true
            textView.requestFirstResponderIfPossible()
        }

        switch focusBindingEchoReconciler.disposition(
            for: parent.isFocused,
            platformIsFocused: textView.window?.firstResponder === textView,
            preservesPlatformFocusDuringHandoff: parent.retainsResponderDuringFocusHandoff
        ) {
        case .activate:
            textView.requestsFirstResponder = true
            textView.requestFirstResponderIfPossible()
        case .preserveLocalActivation:
            textView.requestsFirstResponder = true
        case .preserveDuringHandoff:
            textView.requestsFirstResponder = true
        case .deactivate:
            textView.requestsFirstResponder = false
            guard textView.window?.firstResponder === textView else { return }
            textView.window?.makeFirstResponder(nil)
        }
    }

    func textDidBeginEditing(_ notification: Notification) {
        focusBindingEchoReconciler.recordLocalActivation()
        parent.focusChanged(true)
    }

    func textDidEndEditing(_ notification: Notification) {
        focusBindingEchoReconciler.recordLocalDeactivation()
        parent.focusChanged(false)
    }
}

private extension NativeEditorBlockKind {
    var isHeading: Bool {
        if case .heading = self {
            return true
        }
        return false
    }

    var headingTextStyle: NSFont.TextStyle {
        guard case .heading(let level) = self else { return .body }
        return switch level {
        case 1: .title1
        case 2: .title2
        case 3: .title3
        case 4: .headline
        case 5: .subheadline
        default: .footnote
        }
    }
}

#endif
