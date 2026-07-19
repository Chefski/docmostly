#if os(iOS)
import SwiftUI
import UIKit

@MainActor
extension NativeEditorUITextView {
    func updateRemotePresence(_ segments: [NativeEditorRemotePresenceSegment]) {
        guard renderedRemotePresenceSegments != segments || remotePresenceRenderingIsInvalid else { return }

        remotePresenceOverlayViews.forEach { $0.removeFromSuperview() }
        remotePresenceOverlayViews = []
        renderedRemotePresenceSegments = segments
        remotePresenceRenderingIsInvalid = false

        for segment in segments {
            let overlay = NativeEditorRemotePresenceUIView(segment: segment)
            addSubview(overlay)
            remotePresenceOverlayViews.append(overlay)
        }

        accessibilityHint = segments.isEmpty
            ? nil
            : "Remote presence: \(segments.map(\.accessibilityDescription).uniqued().joined(separator: ", "))"
        layoutRemotePresenceOverlays()
        setNeedsDisplay()
    }

    func invalidateRemotePresenceRendering() {
        remotePresenceRenderingIsInvalid = true
    }

    func layoutRemotePresenceOverlays() {
        for (view, segment) in zip(remotePresenceOverlayViews, renderedRemotePresenceSegments) {
            guard let overlay = view as? NativeEditorRemotePresenceUIView else { continue }
            let caretRect = segment.caretOffset.map(remoteCaretRect(utf16Offset:))
            overlay.place(
                selectionRects: remoteSelectionRects(for: segment.characterRange),
                caretRect: caretRect,
                in: bounds
            )
        }
    }

    private func remoteCaretRect(utf16Offset: Int) -> CGRect {
        let safeOffset = min(max(utf16Offset, 0), textStorage.length)
        guard let position = position(from: beginningOfDocument, offset: safeOffset) else {
            return CGRect(
                origin: CGPoint(x: textContainerInset.left, y: textContainerInset.top),
                size: CGSize(width: 2, height: font?.lineHeight ?? 20)
            )
        }
        var rect = caretRect(for: position)
        if rect.height <= 0 {
            rect.size.height = font?.lineHeight ?? 20
        }
        return rect
    }

    private func remoteSelectionRects(for characterRange: Range<Int>) -> [CGRect] {
        let textLength = textStorage.length
        let lowerBound = min(max(characterRange.lowerBound, 0), textLength)
        let upperBound = min(max(characterRange.upperBound, lowerBound), textLength)
        guard lowerBound < upperBound else { return [] }
        guard
            let start = position(from: beginningOfDocument, offset: lowerBound),
            let end = position(from: beginningOfDocument, offset: upperBound),
            let range = textRange(from: start, to: end)
        else {
            return []
        }

        return selectionRects(for: range)
            .map(\.rect)
            .filter { $0.isNull == false && $0.isInfinite == false && $0.width > 0 && $0.height > 0 }
    }
}

@MainActor
private final class NativeEditorRemotePresenceUIView: UIView {
    private let caretView = UIView()
    private let label = UILabel()
    private var selectionViews: [UIView] = []
    private let selectionColor: UIColor

    init(segment: NativeEditorRemotePresenceSegment) {
        let color = Color(docmostlyHex: segment.colorName).map(UIColor.init) ?? .secondaryLabel
        selectionColor = color.withAlphaComponent(UIAccessibility.isDarkerSystemColorsEnabled ? 0.32 : 0.20)
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        backgroundColor = .clear

        caretView.backgroundColor = color
        caretView.layer.cornerRadius = 1
        label.text = segment.name
        label.font = .preferredFont(forTextStyle: .caption2)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = Self.readableForegroundColor(for: color)
        label.backgroundColor = color
        label.layer.cornerRadius = 4
        label.layer.masksToBounds = true
        label.layer.borderColor = UIColor.label.withAlphaComponent(0.45).cgColor
        label.layer.borderWidth = UIAccessibility.isDarkerSystemColorsEnabled ? 1 : 0.5
        label.textAlignment = .center

        addSubview(caretView)
        addSubview(label)
    }

    private static func readableForegroundColor(for backgroundColor: UIColor) -> UIColor {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard backgroundColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return .label
        }

        let luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        return luminance > 0.55 ? .black : .white
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    func place(selectionRects: [CGRect], caretRect: CGRect?, in bounds: CGRect) {
        frame = bounds
        selectionViews.forEach { $0.removeFromSuperview() }
        selectionViews = selectionRects.map { selectionRect in
            let view = UIView(frame: selectionRect.offsetBy(dx: -bounds.minX, dy: -bounds.minY))
            view.backgroundColor = selectionColor
            view.isUserInteractionEnabled = false
            insertSubview(view, belowSubview: caretView)
            return view
        }

        guard let caretRect else {
            caretView.isHidden = true
            label.isHidden = true
            return
        }

        caretView.isHidden = false
        label.isHidden = false
        let localCaretRect = caretRect.offsetBy(dx: -bounds.minX, dy: -bounds.minY)
        let localBounds = CGRect(origin: .zero, size: bounds.size)
        let labelSize = label.sizeThatFits(CGSize(width: min(localBounds.width * 0.6, 180), height: 40))
        let paddedLabelSize = CGSize(width: labelSize.width + 10, height: labelSize.height + 4)
        let labelY = localCaretRect.minY >= paddedLabelSize.height + 2
            ? localCaretRect.minY - paddedLabelSize.height - 2
            : localCaretRect.maxY + 2
        let labelX = min(
            max(localCaretRect.minX, localBounds.minX),
            max(localBounds.maxX - paddedLabelSize.width, localBounds.minX)
        )
        caretView.frame = CGRect(
            x: localCaretRect.minX,
            y: localCaretRect.minY,
            width: 2,
            height: max(localCaretRect.height, 1)
        )
        label.frame = CGRect(
            x: labelX,
            y: labelY,
            width: paddedLabelSize.width,
            height: paddedLabelSize.height
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
