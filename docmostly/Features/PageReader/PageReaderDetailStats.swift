import Foundation

nonisolated struct PageReaderDetailStats: Equatable, Sendable {
    let wordCount: Int
    let characterCount: Int

    static func stats(in document: NativeEditorDocument) -> Self {
        let text = document.blocks
            .map { String($0.text.characters).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")

        let words = text.split { character in
            character.isWhitespace || character.isNewline
        }

        return PageReaderDetailStats(wordCount: words.count, characterCount: text.count)
    }
}
