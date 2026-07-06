import Foundation

nonisolated struct PageReaderDetailStats: Equatable, Sendable {
    let wordCount: Int
    let characterCount: Int

    static func stats(in document: NativeEditorDocument) -> Self {
        let text = document.blocks
            .flatMap(textSegments)
            .filter { $0.isEmpty == false }
            .joined(separator: "\n")

        let words = text.split { character in
            character.isWhitespace || character.isNewline
        }

        return PageReaderDetailStats(wordCount: words.count, characterCount: text.count)
    }

    private static func textSegments(from block: NativeEditorBlock) -> [String] {
        switch block.kind {
        case .table(let table):
            table.rows.flatMap { row in
                row.cells.map { cell in
                    cell.plainText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        case .paragraph, .heading, .bulletListItem, .orderedListItem, .taskListItem, .blockquote, .codeBlock,
                .image, .video, .audio, .pdf, .attachment, .callout, .details, .pageBreak, .divider, .columns,
                .subpages, .transclusionSource, .transclusionReference, .base, .embed, .drawio, .excalidraw,
                .mathBlock, .unsupported:
            [String(block.text.characters).trimmingCharacters(in: .whitespacesAndNewlines)]
        }
    }
}
