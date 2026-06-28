import Foundation

nonisolated enum AttachmentExtractor {
    static let maximumHTMLCharacters = 2_000_000
    static let maximumLinks = 100
    static let maximumFileNameCharacters = 512

    static func extractLinks(fromHTML html: String) -> [DocmostAttachmentLink] {
        guard html.count <= maximumHTMLCharacters else { return [] }
        var links: [DocmostAttachmentLink] = []
        var remaining = html[...]

        while links.count < maximumLinks, let range = remaining.range(of: "/api/files/") {
            let afterPrefix = remaining[range.upperBound...]
            let end = afterPrefix.firstIndex { character in
                character == "\"" || character == "'" || character == "<" || character.isWhitespace
            } ?? afterPrefix.endIndex

            let suffix = String(afterPrefix[..<end])
            let parts = suffix.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)

            if parts.count == 2 {
                let id = String(parts[0])
                let fileName = String(parts[1]).removingPercentEncoding ?? String(parts[1])
                guard isSafeSegment(id), isSafeFileName(fileName) else {
                    remaining = afterPrefix[end...]
                    continue
                }
                let path = "/api/files/\(id)/\(parts[1])"
                let link = DocmostAttachmentLink(id: id, fileName: fileName, path: path)
                if links.contains(link) == false {
                    links.append(link)
                }
            }

            remaining = afterPrefix[end...]
        }

        return links
    }

    private static func isSafeSegment(_ value: String) -> Bool {
        value.isEmpty == false &&
            value != "." &&
            value != ".." &&
            value.contains("/") == false &&
            value.contains("\\") == false
    }

    private static func isSafeFileName(_ fileName: String) -> Bool {
        guard fileName.isEmpty == false, fileName.count <= maximumFileNameCharacters else {
            return false
        }
        let pathSeparators = CharacterSet(charactersIn: "/\\")
        return fileName != "." &&
            fileName != ".." &&
            fileName.rangeOfCharacter(from: pathSeparators) == nil
    }
}
