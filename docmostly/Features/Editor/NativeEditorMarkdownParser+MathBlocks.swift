import Foundation

extension NativeEditorMarkdownParser {
    static func singleLineMathFenceBlock(from line: String) -> NativeEditorBlock? {
        guard
            line.hasPrefix("$$"),
            line.hasPrefix("$$$") == false,
            line.hasSuffix("$$")
        else {
            return nil
        }

        let contentStart = line.index(line.startIndex, offsetBy: 2)
        let contentEnd = line.index(line.endIndex, offsetBy: -2)
        guard contentStart <= contentEnd else { return nil }

        let mathText = String(line[contentStart..<contentEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard mathText.isEmpty == false else { return nil }

        let math = NativeEditorMathBlock(text: mathText)
        return NativeEditorBlock(
            kind: .mathBlock(math),
            text: AttributedString(NativeEditorDocument.previewText(for: .mathBlock(math))),
            alignment: .left,
            rawNode: NativeEditorRichBlockNodeFactory.mathBlockNode(from: math)
        )
    }
}
