#if os(macOS)
import AppKit

nonisolated enum NativeEditorPlatformTypingAttributes {
    static func attributes(
        baseFont: NSFont,
        marks: Set<NativeEditorInlineMark>,
        kind: NativeEditorBlockKind,
        paragraphStyle: NSParagraphStyle
    ) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font(baseFont: baseFont, marks: marks, kind: kind),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraphStyle
        ]
        if marks.contains(.underline) {
            attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        if marks.contains(.strikethrough) {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        }
        if marks.contains(.subscript) {
            attributes[.baselineOffset] = -4.0
        } else if marks.contains(.superscript) {
            attributes[.baselineOffset] = 4.0
        }
        return attributes
    }

    private static func font(
        baseFont: NSFont,
        marks: Set<NativeEditorInlineMark>,
        kind: NativeEditorBlockKind
    ) -> NSFont {
        let hasStrongEmphasis = marks.contains(.bold)
        let usesHeavyHeadingWeight = hasStrongEmphasis && kind.isTypingAttributesHeading
        let emphasizedWeight: NSFont.Weight = usesHeavyHeadingWeight ? .heavy : .regular
        var font: NSFont
        if marks.contains(.code) {
            font = NSFont.monospacedSystemFont(
                ofSize: baseFont.pointSize,
                weight: emphasizedWeight
            )
        } else if usesHeavyHeadingWeight {
            font = NSFont.systemFont(ofSize: baseFont.pointSize, weight: emphasizedWeight)
        } else {
            font = baseFont
        }
        if hasStrongEmphasis && usesHeavyHeadingWeight == false {
            font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        }
        if marks.contains(.italic) {
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
        }
        return font
    }
}

private extension NativeEditorBlockKind {
    nonisolated var isTypingAttributesHeading: Bool {
        if case .heading = self {
            return true
        }
        return false
    }
}
#endif
