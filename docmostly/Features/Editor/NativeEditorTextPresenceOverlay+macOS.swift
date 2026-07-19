#if os(macOS)
import AppKit
import SwiftUI

@MainActor
extension NativeEditorNSTextView {
    func updateRemotePresence(_ segments: [NativeEditorRemotePresenceSegment]) {
        guard renderedRemotePresenceSegments != segments || remotePresenceRenderingIsInvalid else { return }

        removeRemotePresenceHighlights()
        remotePresenceOverlayViews.forEach { $0.removeFromSuperview() }
        remotePresenceOverlayViews = []
        renderedRemotePresenceSegments = segments
        remotePresenceRenderingIsInvalid = false

        let textLength = textStorage?.length ?? 0
        for segment in segments {
            let safeLocation = min(max(segment.characterRange.lowerBound, 0), textLength)
            let safeRange = NSRange(
                location: safeLocation,
                length: min(max(segment.characterRange.count, 0), max(textLength - safeLocation, 0))
            )
            if safeRange.length > 0, let layoutManager {
                let color = platformColor(for: segment.colorName)
                let opacity: CGFloat = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast ? 0.34 : 0.20
                layoutManager.addTemporaryAttribute(
                    .backgroundColor,
                    value: color.withAlphaComponent(opacity),
                    forCharacterRange: safeRange
                )
                remotePresenceHighlightRanges.append(safeRange)
            }

            if segment.caretOffset != nil {
                let overlay = NativeEditorRemotePresenceNSView(segment: segment)
                addSubview(overlay)
                remotePresenceOverlayViews.append(overlay)
            }
        }

        setAccessibilityHelp(segments.isEmpty
            ? nil
            : "Remote presence: \(segments.map(\.accessibilityDescription).uniqued().joined(separator: ", "))")
        layoutRemotePresenceOverlays()
        needsDisplay = true
    }

    func invalidateRemotePresenceRendering() {
        remotePresenceRenderingIsInvalid = true
    }

    func layoutRemotePresenceOverlays() {
        let caretSegments = renderedRemotePresenceSegments.filter { $0.caretOffset != nil }
        for (view, segment) in zip(remotePresenceOverlayViews, caretSegments) {
            guard let overlay = view as? NativeEditorRemotePresenceNSView else { continue }
            guard let caretOffset = segment.caretOffset else { continue }
            overlay.place(at: remoteCaretRect(utf16Offset: caretOffset), in: bounds)
        }
    }

    private func removeRemotePresenceHighlights() {
        guard let layoutManager else { return }
        let textLength = textStorage?.length ?? 0
        for range in remotePresenceHighlightRanges where NSMaxRange(range) <= textLength {
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: range)
        }
        remotePresenceHighlightRanges = []
    }

    private func remoteCaretRect(utf16Offset: Int) -> CGRect {
        guard let layoutManager, let textContainer else {
            return CGRect(
                origin: textContainerOrigin,
                size: CGSize(width: 2, height: font?.boundingRectForFont.height ?? 20)
            )
        }

        let textLength = textStorage?.length ?? 0
        let safeOffset = min(max(utf16Offset, 0), textLength)
        let lineHeight = font?.boundingRectForFont.height ?? 20
        guard textLength > 0 else {
            return CGRect(origin: textContainerOrigin, size: CGSize(width: 2, height: lineHeight))
        }

        let characterIndex = min(safeOffset, textLength - 1)
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: characterIndex)
        let glyphRect = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            in: textContainer
        )
        let lineRect = layoutManager.lineFragmentUsedRect(
            forGlyphAt: glyphIndex,
            effectiveRange: nil
        )
        let caretX = safeOffset == textLength ? glyphRect.maxX : glyphRect.minX
        return CGRect(
            x: textContainerOrigin.x + caretX,
            y: textContainerOrigin.y + lineRect.minY,
            width: 2,
            height: max(lineRect.height, lineHeight)
        )
    }

    private func platformColor(for colorName: String) -> NSColor {
        guard let color = Color(docmostlyHex: colorName) else { return .secondaryLabelColor }
        return NSColor(color)
    }
}

@MainActor
private final class NativeEditorRemotePresenceNSView: NSView {
    private let caretView = NSView()
    private let label = NSTextField(labelWithString: "")

    init(segment: NativeEditorRemotePresenceSegment) {
        super.init(frame: .zero)
        wantsLayer = true

        let color = Color(docmostlyHex: segment.colorName).map(NSColor.init) ?? .secondaryLabelColor
        caretView.wantsLayer = true
        caretView.layer?.backgroundColor = color.cgColor
        caretView.layer?.cornerRadius = 1
        label.stringValue = segment.name
        label.font = .preferredFont(forTextStyle: .caption2, options: [:])
        label.textColor = Self.readableForegroundColor(for: color)
        label.backgroundColor = color
        label.drawsBackground = true
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.alignment = .center
        label.wantsLayer = true
        label.layer?.cornerRadius = 4
        label.layer?.borderColor = NSColor.labelColor.withAlphaComponent(0.45).cgColor
        label.layer?.borderWidth = NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast ? 1 : 0.5

        addSubview(caretView)
        addSubview(label)
        setAccessibilityElement(false)
    }

    private static func readableForegroundColor(for backgroundColor: NSColor) -> NSColor {
        guard let color = backgroundColor.usingColorSpace(.sRGB) else { return .labelColor }
        let luminance = (0.2126 * color.redComponent)
            + (0.7152 * color.greenComponent)
            + (0.0722 * color.blueComponent)
        return luminance > 0.55 ? .black : .white
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    func place(at caretRect: CGRect, in bounds: CGRect) {
        let intrinsic = label.intrinsicContentSize
        let labelSize = CGSize(
            width: min(intrinsic.width + 10, max(bounds.width * 0.6, 40)),
            height: intrinsic.height + 4
        )
        let labelY = caretRect.minY >= labelSize.height + 2
            ? caretRect.minY - labelSize.height - 2
            : caretRect.maxY + 2
        let labelX = min(max(caretRect.minX, bounds.minX), max(bounds.maxX - labelSize.width, bounds.minX))
        let labelRect = CGRect(origin: CGPoint(x: labelX, y: labelY), size: labelSize)
        let union = caretRect.union(labelRect)

        frame = union.integral
        caretView.frame = CGRect(
            x: caretRect.minX - frame.minX,
            y: caretRect.minY - frame.minY,
            width: 2,
            height: max(caretRect.height, 1)
        )
        label.frame = CGRect(
            x: labelRect.minX - frame.minX,
            y: labelRect.minY - frame.minY,
            width: labelRect.width,
            height: labelRect.height
        )
    }
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
#endif
