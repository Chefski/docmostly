import Foundation

extension NativeEditorMarkdownParser {
    static func iframeEmbedMarkdownBlock(from line: String) -> NativeEditorBlock? {
        guard let link = iframeMarkdownLink(from: line), isWebEmbedSource(link.source) else {
            return nil
        }

        let embed = NativeEditorEmbedBlock(
            source: link.source,
            provider: "iframe",
            alignment: nil,
            width: nil,
            height: nil
        )
        return NativeEditorBlock(
            kind: .embed(embed),
            text: AttributedString(link.source),
            alignment: .left,
            rawNode: NativeEditorRichBlockNodeFactory.embedNode(from: embed)
        )
    }

    private static func iframeMarkdownLink(from line: String) -> (label: String, source: String)? {
        guard line.hasPrefix("["), let closeLabelIndex = line.firstIndex(of: "]") else {
            return nil
        }

        let openDestinationIndex = line.index(after: closeLabelIndex)
        guard
            openDestinationIndex < line.endIndex,
            line[openDestinationIndex] == "(",
            let closeDestinationIndex = line.lastIndex(of: ")"),
            closeDestinationIndex == line.index(before: line.endIndex)
        else {
            return nil
        }

        let labelStartIndex = line.index(after: line.startIndex)
        let label = unescapedMarkdownLinkLabel(String(line[labelStartIndex..<closeLabelIndex]))
        let destinationStartIndex = line.index(after: openDestinationIndex)
        let source = markdownEmbedSource(from: String(line[destinationStartIndex..<closeDestinationIndex]))
        guard label == source else { return nil }
        return (label, source)
    }

    private static func markdownEmbedSource(from destination: String) -> String {
        var source = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        if source.hasPrefix("<"), source.hasSuffix(">") {
            source.removeFirst()
            source.removeLast()
        }
        return source.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func unescapedMarkdownLinkLabel(_ text: String) -> String {
        var result = ""
        var isEscaped = false

        for character in text {
            if isEscaped {
                result.append(character)
                isEscaped = false
            } else if character == "\\" {
                isEscaped = true
            } else {
                result.append(character)
            }
        }

        return isEscaped ? result + "\\" : result
    }

    private static func isWebEmbedSource(_ source: String) -> Bool {
        guard
            let components = URLComponents(string: source),
            let scheme = components.scheme?.lowercased(),
            scheme == "https" || scheme == "http",
            components.host?.isEmpty == false
        else {
            return false
        }

        return true
    }
}
