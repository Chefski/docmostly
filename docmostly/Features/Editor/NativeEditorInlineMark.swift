import Foundation
import SwiftUI

nonisolated enum NativeEditorInlineMark: CaseIterable, Hashable, Sendable {
    case bold
    case italic
    case underline
    case strikethrough
    case code
    case `subscript`
    case superscript

    func toggle(in attributes: inout AttributeContainer) {
        set(isActive(in: attributes) == false, in: &attributes)
    }

    func toggle(in text: inout AttributedString) {
        if case .underline = self {
            text.underlineStyle = text.underlineStyle == nil ? .single : nil
            return
        }

        if let baselineOffset {
            text.baselineOffset = text.baselineOffset == baselineOffset ? nil : baselineOffset
            return
        }

        guard let intent else { return }
        var currentIntent = text.inlinePresentationIntent ?? []
        if currentIntent.contains(intent) {
            currentIntent.remove(intent)
        } else {
            currentIntent.insert(intent)
        }
        text.inlinePresentationIntent = currentIntent.isEmpty ? nil : currentIntent
    }

    func isActive(in attributes: AttributeContainer) -> Bool {
        if case .underline = self {
            return attributes.underlineStyle != nil
        }

        if let baselineOffset {
            return attributes.baselineOffset == baselineOffset
        }

        guard let intent else { return false }
        return attributes.inlinePresentationIntent?.contains(intent) == true
    }

    func set(_ isActive: Bool, in attributes: inout AttributeContainer) {
        if case .underline = self {
            attributes.underlineStyle = isActive ? .single : nil
            return
        }

        if let baselineOffset {
            attributes.baselineOffset = isActive ? baselineOffset : nil
            return
        }

        guard let intent else { return }
        var currentIntent = attributes.inlinePresentationIntent ?? []
        if isActive {
            currentIntent.insert(intent)
        } else {
            currentIntent.remove(intent)
        }
        attributes.inlinePresentationIntent = currentIntent.isEmpty ? nil : currentIntent
    }

    static func setActiveMarks(_ marks: Set<Self>, in attributes: inout AttributeContainer) {
        for mark in allCases where mark != .subscript && mark != .superscript {
            mark.set(marks.contains(mark), in: &attributes)
        }
        if marks.contains(.subscript) {
            attributes.baselineOffset = -4
        } else if marks.contains(.superscript) {
            attributes.baselineOffset = 4
        } else {
            attributes.baselineOffset = nil
        }
    }

    static func activeMarks(
        for selection: AttributedTextSelection,
        in text: AttributedString
    ) -> Set<Self> {
        switch selection.indices(in: text) {
        case .insertionPoint(let index):
            return activeMarks(in: inheritedAttributes(at: index, in: text))
        case .ranges(let ranges):
            guard ranges.isEmpty == false else {
                return activeMarks(in: inheritedAttributes(at: text.endIndex, in: text))
            }
            return Set(allCases.filter { mark in
                ranges.ranges.allSatisfy { range in
                    text[range].runs.allSatisfy { mark.isActive(in: $0.attributes) }
                }
            })
        }
    }

    private static func activeMarks(in attributes: AttributeContainer?) -> Set<Self> {
        guard let attributes else { return [] }
        return Set(allCases.filter { $0.isActive(in: attributes) })
    }

    private static func inheritedAttributes(
        at insertionIndex: AttributedString.Index,
        in text: AttributedString
    ) -> AttributeContainer? {
        if insertionIndex > text.startIndex {
            let previousIndex = text.characters.index(before: insertionIndex)
            if let attributes = text[previousIndex..<insertionIndex].runs.first?.attributes,
               attributes.hasNativeEditorAtomicInlineAttribute == false {
                return attributes
            }
        }

        if insertionIndex < text.endIndex {
            let nextIndex = text.characters.index(after: insertionIndex)
            let attributes = text[insertionIndex..<nextIndex].runs.first?.attributes
            if attributes?.hasNativeEditorAtomicInlineAttribute == false {
                return attributes
            }
        }

        return nil
    }

    private var intent: InlinePresentationIntent? {
        switch self {
        case .bold:
            .stronglyEmphasized
        case .italic:
            .emphasized
        case .underline:
            nil
        case .strikethrough:
            .strikethrough
        case .code:
            .code
        case .subscript, .superscript:
            nil
        }
    }

    private var baselineOffset: Double? {
        switch self {
        case .subscript:
            -4
        case .superscript:
            4
        case .bold, .italic, .underline, .strikethrough, .code:
            nil
        }
    }
}
