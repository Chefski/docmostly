#if os(macOS)
import AppKit
import SwiftUI

struct NativeEditorTextInputView: NSViewRepresentable {
    @Binding var block: NativeEditorBlock
    @Binding var isFocused: Bool

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
        textView.isEditable = true
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
        textView.updateRemotePresence(remotePresenceSegments)
        return textView
    }

    func updateNSView(_ textView: NativeEditorNSTextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.configure(textView)

        context.coordinator.updateFromBoundBlock(textView)
        context.coordinator.updateFocus(textView)
        textView.updateRemotePresence(remotePresenceSegments)
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
    private var pendingSelectionCorrection: Range<Int>?
    private var bindingEchoReconciler = NativeEditorTextBindingEchoReconciler()
    private var focusBindingEchoReconciler = NativeEditorFocusBindingEchoReconciler()

    init(parent: NativeEditorTextInputView) {
        self.parent = parent
        sourceText = parent.block.text
        renderedPlainText = String(parent.block.text.characters)
        super.init()
    }

    func configure(_ textView: NSTextView) {
        let font = platformFont(for: parent.block.kind)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = platformAlignment(parent.block.alignment)

        textView.font = font
        textView.alignment = paragraphStyle.alignment
        textView.typingAttributes = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]
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

    func updateFocus(_ textView: NativeEditorNSTextView) {
        switch focusBindingEchoReconciler.disposition(
            for: parent.isFocused,
            platformIsFocused: textView.window?.firstResponder === textView
        ) {
        case .activate:
            textView.requestsFirstResponder = true
            textView.requestFirstResponderIfPossible()
        case .preserveLocalActivation:
            textView.requestsFirstResponder = true
        case .deactivate:
            textView.requestsFirstResponder = false
            guard textView.window?.firstResponder === textView else { return }
            textView.window?.makeFirstResponder(nil)
        }
    }

    func textDidBeginEditing(_ notification: Notification) {
        focusBindingEchoReconciler.recordLocalActivation()
        parent.isFocused = true
    }

    func textDidEndEditing(_ notification: Notification) {
        focusBindingEchoReconciler.recordLocalDeactivation()
        parent.isFocused = false
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
        let updatedSource = safeDelta.applying(to: sourceText)
        let updatedSourcePlainText = String(updatedSource.characters)
        bindingEchoReconciler.recordLocalTransition(from: sourceText, to: updatedSource)
        sourceText = updatedSource

        if updatedSourcePlainText == updatedPlainText {
            renderedPlainText = updatedPlainText
            synchronizeSelection(from: textView)
        } else {
            let insertionOffset = min(safeDelta.insertionCharacterOffset, updatedSource.characters.count)
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
        alignment: NSTextAlignment
    ) -> NSAttributedString {
        let rendered = NSMutableAttributedString(
            attributedString: NSAttributedString(text.nativeEditorPlatformRenderableText)
        )
        let fullRange = NSRange(location: 0, length: rendered.length)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment

        rendered.addAttribute(.font, value: font, range: fullRange)
        applyInlinePresentationFonts(from: text, baseFont: font, to: rendered)
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
        to rendered: NSMutableAttributedString
    ) {
        let plainText = String(text.characters)
        for run in text.runs {
            guard let intent = run.inlinePresentationIntent else { continue }
            let lowerBound = text.characters.distance(from: text.startIndex, to: run.range.lowerBound)
            let upperBound = text.characters.distance(from: text.startIndex, to: run.range.upperBound)
            let characterRange = lowerBound..<upperBound
            let range = NativeEditorCharacterRange.nsRange(for: characterRange, in: plainText)
            var runFont = intent.contains(.code)
                ? NSFont.monospacedSystemFont(ofSize: baseFont.pointSize, weight: .regular)
                : baseFont
            if intent.contains(.stronglyEmphasized) {
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
        case .heading(let level):
            return NSFont.preferredFont(
                forTextStyle: level == 1 ? .title1 : .title2,
                options: [:]
            )
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

@MainActor
final class NativeEditorNSTextView: NSTextView {
    var requestsFirstResponder = false
    var renderedRemotePresenceSegments: [NativeEditorRemotePresenceSegment] = []
    var remotePresenceHighlightRanges: [NSRange] = []
    var remotePresenceOverlayViews: [NSView] = []
    var remotePresenceRenderingIsInvalid = true

    override func layout() {
        super.layout()
        layoutRemotePresenceOverlays()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        requestFirstResponderIfPossible()
    }

    func requestFirstResponderIfPossible() {
        guard
            requestsFirstResponder,
            let window,
            window.firstResponder !== self
        else {
            return
        }
        window.makeFirstResponder(self)
    }
}
#endif
