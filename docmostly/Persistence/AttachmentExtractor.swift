import Foundation

nonisolated enum AttachmentExtractor {
    static func extractLinks(fromHTML html: String) -> [DocmostAttachmentLink] {
        var links: [DocmostAttachmentLink] = []
        var remaining = html[...]

        while let range = remaining.range(of: "/api/files/") {
            let afterPrefix = remaining[range.upperBound...]
            let end = afterPrefix.firstIndex { character in
                character == "\"" || character == "'" || character == "<" || character.isWhitespace
            } ?? afterPrefix.endIndex

            let suffix = String(afterPrefix[..<end])
            let parts = suffix.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)

            if parts.count == 2 {
                let id = String(parts[0])
                let fileName = String(parts[1]).removingPercentEncoding ?? String(parts[1])
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
}
