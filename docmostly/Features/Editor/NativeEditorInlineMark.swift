import Foundation

enum NativeEditorInlineMark {
    case bold
    case italic
    case strikethrough
    case code

    func toggle(in attributes: inout AttributeContainer) {
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
        case .strikethrough:
            .strikethrough
        case .code:
            .code
        }
    }
}
