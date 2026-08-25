#if os(iOS)
import UIKit

nonisolated enum NativeEditorPlatformTypingAttributes {
    static func attributes(
        baseFont: UIFont,
        marks: Set<NativeEditorInlineMark>,
        kind: NativeEditorBlockKind,
        paragraphStyle: NSParagraphStyle
    ) -> [NSAttributedString.Key: Any] {
        var attributes: [NSAttributedString.Key: Any] = [
            .font: font(baseFont: baseFont, marks: marks, kind: kind),
            .foregroundColor: UIColor.label,
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
        baseFont: UIFont,
        marks: Set<NativeEditorInlineMark>,
        kind: NativeEditorBlockKind
    ) -> UIFont {
        let hasStrongEmphasis = marks.contains(.bold)
        let usesHeavyHeadingWeight = hasStrongEmphasis && kind.isTypingAttributesHeading
        var descriptor = usesHeavyHeadingWeight
            ? UIFont.systemFont(ofSize: baseFont.pointSize, weight: .heavy).fontDescriptor
            : baseFont.fontDescriptor
        if marks.contains(.code), let monospacedDescriptor = descriptor.withDesign(.monospaced) {
            descriptor = monospacedDescriptor
        }
        var traits = descriptor.symbolicTraits
        if hasStrongEmphasis && usesHeavyHeadingWeight == false {
            traits.insert(.traitBold)
        }
        if marks.contains(.italic) {
            traits.insert(.traitItalic)
        }
        guard let styledDescriptor = descriptor.withSymbolicTraits(traits) else {
            return baseFont
        }
        return UIFont(descriptor: styledDescriptor, size: baseFont.pointSize)
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
