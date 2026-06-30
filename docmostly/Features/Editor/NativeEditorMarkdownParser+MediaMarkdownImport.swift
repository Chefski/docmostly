import Foundation

extension NativeEditorMarkdownParser {
    static func appendImageMarkdownBlocksWithTrailingText(
        in lines: [String],
        startingAt index: inout Array<String>.Index,
        to importedBlocks: inout [NativeEditorBlock]
    ) -> Bool {
        let line = lines[index].trimmingCharacters(in: .whitespaces)
        guard let blocks = imageMarkdownBlocksWithTrailingText(from: line) else { return false }
        importedBlocks.append(contentsOf: blocks)
        index = lines.index(after: index)
        return true
    }

    private static func imageMarkdownBlocksWithTrailingText(from line: String) -> [NativeEditorBlock]? {
        guard
            line.hasPrefix("!["),
            let closeAltIndex = line.firstIndex(of: "]")
        else {
            return nil
        }

        let openDestinationIndex = line.index(after: closeAltIndex)
        guard
            openDestinationIndex < line.endIndex,
            line[openDestinationIndex] == "(",
            let closeDestinationIndex = closingMarkdownLinkDestinationIndex(
                in: line[...],
                startingAt: line.index(after: openDestinationIndex)
            )
        else {
            return nil
        }

        let trailingStartIndex = line.index(after: closeDestinationIndex)
        let trailingText = String(line[trailingStartIndex...]).trimmingCharacters(in: .whitespaces)
        guard trailingText.isEmpty == false else { return nil }

        let imageMarkdown = String(line[...closeDestinationIndex])
        guard let imageBlock = imageMarkdownBlock(from: imageMarkdown) else { return nil }

        return [
            imageBlock,
            NativeEditorBlock(kind: .paragraph, text: inlineText(from: trailingText), alignment: .left)
        ]
    }
}
