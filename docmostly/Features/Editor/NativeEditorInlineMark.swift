import Foundation
import SwiftUI

enum NativeEditorInlineMark {
    case bold
    case italic
    case underline
    case strikethrough
    case code
    case `subscript`
    case superscript

    func toggle(in attributes: inout AttributeContainer) {
        if case .underline = self {
            attributes.underlineStyle = attributes.underlineStyle == nil ? .single : nil
            return
        }

        if let baselineOffset {
            attributes.baselineOffset = attributes.baselineOffset == baselineOffset ? nil : baselineOffset
            return
        }

        guard let intent else { return }
        var currentIntent = attributes.inlinePresentationIntent ?? []

        if currentIntent.contains(intent) {
            currentIntent.remove(intent)
        } else {
            currentIntent.insert(intent)
        }

        attributes.inlinePresentationIntent = currentIntent.isEmpty ? nil : currentIntent
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
