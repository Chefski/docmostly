import Foundation

struct NativeEditorTextInputActions {
    let handleReturn: (Range<Int>) -> Bool
    let insertHardBreak: (Range<Int>) -> Bool
    let mergeBlockBackward: () -> Bool
}

nonisolated enum NativeEditorReturnKeyBehavior: Equatable {
    case splitBlock
    case insertHardBreak

    static func resolve(
        kind: NativeEditorBlockKind,
        text: AttributedString,
        selection: Range<Int>
    ) -> Self {
        guard case .codeBlock = kind else { return .splitBlock }
        let safeSelection = NativeEditorCharacterRange.clamped(selection, count: text.characters.count)
        let exitsCodeBlock = safeSelection.isEmpty &&
            safeSelection.lowerBound == text.characters.count &&
            String(text.characters.suffix(2)) == "\n\n"
        return exitsCodeBlock ? .splitBlock : .insertHardBreak
    }
}
