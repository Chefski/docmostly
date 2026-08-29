#if os(iOS)
import SwiftUI
import UIKit

struct NativeEditorTextInputView: UIViewRepresentable {
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

    func makeUIView(context: Context) -> NativeEditorUITextView {
        let textView = NativeEditorUITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.isEditable = isEditable
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.adjustsFontForContentSizeCategory = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.accessibilityLabel = accessibilityLabel
        textView.shiftReturnAction = { [weak coordinator = context.coordinator, weak textView] in
            guard let coordinator, let textView else { return }
            coordinator.insertHardBreak(in: textView)
        }
        textView.backspaceAtStartAction = { [weak coordinator = context.coordinator] in
            coordinator?.mergeBlockBackward() ?? false
        }
        context.coordinator.configure(textView)
        context.coordinator.applySource(to: textView)
        context.coordinator.updateFocus(textView)
        textView.updateRemotePresence(remotePresenceSegments)
        return textView
    }

    func updateUIView(_ textView: NativeEditorUITextView, context: Context) {
        context.coordinator.parent = self
        textView.isEditable = isEditable
        context.coordinator.configure(textView)

        context.coordinator.updateFromBoundBlock(textView)
        context.coordinator.updateFocus(textView)
        textView.updateRemotePresence(remotePresenceSegments)
    }

    static func dismantleUIView(
        _ textView: NativeEditorUITextView,
        coordinator: NativeEditorTextInputCoordinator
    ) {
        textView.requestsFirstResponder = false
        if textView.isFirstResponder {
            textView.resignFirstResponder()
        }
        coordinator.parent.focusChanged(false)
        textView.delegate = nil
    }

    func sizeThatFits(
        _ proposal: ProposedViewSize,
        uiView: NativeEditorUITextView,
        context: Context
    ) -> CGSize? {
        guard let width = proposal.width, width.isFinite, width > 0 else { return nil }
        let fittingSize = uiView.sizeThatFits(
            CGSize(width: width, height: .greatestFiniteMagnitude)
        )
        return CGSize(width: width, height: ceil(fittingSize.height))
    }
}

@MainActor
final class NativeEditorTextInputCoordinator: NSObject, UITextViewDelegate {
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

    func configure(_ textView: UITextView) {
        let font = platformFont(for: parent.block.kind)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = platformAlignment(parent.block.alignment)

        textView.font = font
        textView.textAlignment = paragraphStyle.alignment
        textView.typingAttributes = NativeEditorPlatformTypingAttributes.attributes(
            baseFont: font,
            marks: parent.typingInlineMarks,
            kind: parent.block.kind,
            paragraphStyle: paragraphStyle
        )
        textView.accessibilityLabel = parent.accessibilityLabel
    }

    func updateFromBoundBlock(_ textView: UITextView) {
        let boundText = parent.block.text
        if textView.markedTextRange != nil, boundText != sourceText {
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

    func applySource(to textView: UITextView) {
        isApplyingSource = true
        defer { isApplyingSource = false }

        sourceText = parent.block.text
        bindingEchoReconciler.reset()
        renderedPlainText = String(sourceText.characters)
        textView.attributedText = renderedText(
            sourceText,
            font: platformFont(for: parent.block.kind),
            kind: parent.block.kind,
            alignment: platformAlignment(parent.block.alignment)
        )
        (textView as? NativeEditorUITextView)?.invalidateRemotePresenceRendering()
        applyBoundSelectionIfNeeded(to: textView)
    }

    func applyBoundSelectionIfNeeded(to textView: UITextView) {
        guard
            let characterRange = NativeEditorCharacterRange.characterRange(
                for: parent.block.selection,
                in: parent.block.text
            )
        else {
            return
        }

        let safeRange = NativeEditorAtomicTextRange.selectionRange(
            for: characterRange,
            in: parent.block.text
        )
        let requestedSelection = NativeEditorCharacterRange.nsRange(
            for: safeRange,
            in: textView.text
        )
        if safeRange != characterRange {
            scheduleBoundSelectionCorrection(safeRange)
        }
        guard textView.selectedRange != requestedSelection else { return }

        isApplyingSource = true
        textView.selectedRange = requestedSelection
        isApplyingSource = false
    }

    func updateFocus(_ textView: NativeEditorUITextView) {
        guard parent.isEditable else {
            textView.requestsFirstResponder = false
            guard textView.isFirstResponder else { return }
            textView.resignFirstResponder()
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
            platformIsFocused: textView.isFirstResponder,
            preservesPlatformFocusDuringHandoff: parent.retainsResponderDuringFocusHandoff
        ) {
        case .activate:
            textView.requestsFirstResponder = true
            textView.requestFirstResponderIfPossible()
        case .preserveLocalActivation:
            textView.requestsFirstResponder = true
            return
        case .preserveDuringHandoff:
            textView.requestsFirstResponder = true
            return
        case .deactivate:
            textView.requestsFirstResponder = false
            guard textView.isFirstResponder else { return }
            textView.resignFirstResponder()
        }
    }

    func insertHardBreak(in textView: UITextView) {
        guard let range = selectedCharacterRange(in: textView) else { return }
        _ = parent.actions.insertHardBreak(range)
    }

    func mergeBlockBackward() -> Bool {
        parent.actions.mergeBlockBackward()
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        focusBindingEchoReconciler.recordLocalActivation()
        parent.focusChanged(true)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        focusBindingEchoReconciler.recordLocalDeactivation()
        bindingEchoReconciler.reset()
        parent.focusChanged(false)
    }

    func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        guard let characterRange = NativeEditorCharacterRange.characterRange(for: range, in: textView.text) else {
            return true
        }
        if text == "\n", textView.markedTextRange == nil {
            pendingTextDelta = nil
            return parent.actions.handleReturn(characterRange) == false
        }
        pendingTextDelta = NativeEditorTextDelta(
            replacedCharacterRange: characterRange,
            replacement: text
        )
        textDrivenSelection = pendingTextDelta.map { delta in
            delta.insertionCharacterOffset..<delta.insertionCharacterOffset
        }
        return true
    }

    func textViewDidChange(_ textView: UITextView) {
        guard isApplyingSource == false else { return }
        let updatedPlainText = textView.text ?? ""
        guard let delta = resolvedTextDelta(for: updatedPlainText) else {
            synchronizeSelection(from: textView)
            return
        }

        let safeDelta = delta.adjustedForAtomicInlineContent(in: sourceText)
        let updatedSource = safeDelta.applying(
            to: sourceText,
            typingInlineMarks: parent.typingInlineMarks
        )
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

    func textViewDidChangeSelection(_ textView: UITextView) {
        guard
            isApplyingSource == false,
            textView.text == renderedPlainText
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

    private func synchronizeSelection(from textView: UITextView) {
        pendingSelectionCorrection = nil
        guard let requestedRange = NativeEditorCharacterRange.characterRange(
            for: textView.selectedRange,
            in: textView.text
        ) else {
            return
        }
        let safeRange = NativeEditorAtomicTextRange.selectionRange(for: requestedRange, in: sourceText)
        if safeRange != requestedRange {
            isApplyingSource = true
            textView.selectedRange = NativeEditorCharacterRange.nsRange(for: safeRange, in: textView.text)
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

    private func selectedCharacterRange(in textView: UITextView) -> Range<Int>? {
        guard let range = NativeEditorCharacterRange.characterRange(
            for: textView.selectedRange,
            in: textView.text
        ) else {
            return nil
        }
        return NativeEditorAtomicTextRange.selectionRange(for: range, in: sourceText)
    }

    private func reconcilePlatformText(
        _ source: AttributedString,
        selection: Range<Int>,
        in textView: UITextView
    ) {
        isApplyingSource = true
        defer { isApplyingSource = false }

        renderedPlainText = String(source.characters)
        textView.attributedText = renderedText(
            source,
            font: platformFont(for: parent.block.kind),
            kind: parent.block.kind,
            alignment: platformAlignment(parent.block.alignment)
        )
        (textView as? NativeEditorUITextView)?.invalidateRemotePresenceRendering()
        textView.selectedRange = NativeEditorCharacterRange.nsRange(
            for: selection,
            in: renderedPlainText
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
        font: UIFont,
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
            rendered.addAttribute(.foregroundColor, value: UIColor.label, range: range)
        }
        rendered.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
        return rendered
    }

    private func applyInlinePresentationFonts(
        from text: AttributedString,
        baseFont: UIFont,
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
            var descriptor = usesHeavyHeadingWeight
                ? UIFont.systemFont(ofSize: baseFont.pointSize, weight: .heavy).fontDescriptor
                : baseFont.fontDescriptor
            if intent.contains(.code), let monospacedDescriptor = descriptor.withDesign(.monospaced) {
                descriptor = monospacedDescriptor
            }
            var traits = descriptor.symbolicTraits
            if hasStrongEmphasis && usesHeavyHeadingWeight == false {
                traits.insert(.traitBold)
            }
            if intent.contains(.emphasized) {
                traits.insert(.traitItalic)
            }
            if let styledDescriptor = descriptor.withSymbolicTraits(traits) {
                rendered.addAttribute(
                    .font,
                    value: UIFont(descriptor: styledDescriptor, size: baseFont.pointSize),
                    range: range
                )
            }
            if intent.contains(.strikethrough) {
                rendered.addAttribute(
                    .strikethroughStyle,
                    value: NSUnderlineStyle.single.rawValue,
                    range: range
                )
            }
        }
    }

    private func platformFont(for kind: NativeEditorBlockKind) -> UIFont {
        switch kind {
        case .heading:
            let font = UIFont.preferredFont(forTextStyle: kind.headingTextStyle)
            var traits = font.fontDescriptor.symbolicTraits
            traits.insert(.traitBold)
            guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else {
                return font
            }
            return UIFont(descriptor: descriptor, size: font.pointSize)
        case .codeBlock:
            let bodyFont = UIFont.preferredFont(forTextStyle: .body)
            let baseFont = UIFont.monospacedSystemFont(ofSize: bodyFont.pointSize, weight: .regular)
            return UIFontMetrics(forTextStyle: .body).scaledFont(for: baseFont)
        default:
            return UIFont.preferredFont(forTextStyle: .body)
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

private extension NativeEditorBlockKind {
    var isHeading: Bool {
        if case .heading = self {
            return true
        }
        return false
    }

    var headingTextStyle: UIFont.TextStyle {
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

@MainActor
final class NativeEditorUITextView: UITextView {
    var requestsFirstResponder = false
    var shiftReturnAction: (() -> Void)?
    var backspaceAtStartAction: (() -> Bool)?
    var renderedRemotePresenceSegments: [NativeEditorRemotePresenceSegment] = []
    var remotePresenceOverlayViews: [UIView] = []
    var remotePresenceRenderingIsInvalid = true

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutRemotePresenceOverlays()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        requestFirstResponderIfPossible()
    }

    func requestFirstResponderIfPossible() {
        guard requestsFirstResponder, window != nil, isFirstResponder == false else { return }
        becomeFirstResponder()
    }

    override var keyCommands: [UIKeyCommand]? {
        var commands = super.keyCommands ?? []
        let shiftReturn = UIKeyCommand(
            input: "\r",
            modifierFlags: .shift,
            action: #selector(handleShiftReturn)
        )
        shiftReturn.wantsPriorityOverSystemBehavior = true
        commands.append(shiftReturn)
        return commands
    }

    override func deleteBackward() {
        if markedTextRange == nil,
           selectedRange.location == 0,
           selectedRange.length == 0,
           backspaceAtStartAction?() == true {
            return
        }
        super.deleteBackward()
    }

    @objc private func handleShiftReturn() {
        shiftReturnAction?()
    }
}
#endif
