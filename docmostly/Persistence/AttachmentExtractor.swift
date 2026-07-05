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
                let metadata = metadata(forLinkAt: range.lowerBound, fallbackID: id, fallbackPath: path, in: html)
                let metadataID = metadata.id.flatMap { isSafeSegment($0) ? $0 : nil }
                let metadataFileName = metadata.fileName.flatMap { isSafeFileName($0) ? $0 : nil }
                let metadataPath = metadata.path.flatMap { $0.hasPrefix("/api/files/") ? $0 : nil }
                let link = DocmostAttachmentLink(
                    id: metadataID ?? id,
                    fileName: metadataFileName ?? fileName,
                    path: metadataPath ?? path,
                    fileSize: metadata.fileSize,
                    mimeType: metadata.mimeType
                )
                if links.contains(where: { $0.id == link.id }) == false {
                    links.append(link)
                }
            }

            remaining = afterPrefix[end...]
        }

        return links
    }

    static func extractLinks(from document: ProseMirrorDocument) -> [DocmostAttachmentLink] {
        var links: [DocmostAttachmentLink] = []
        var nodes = document.content

        while links.count < maximumLinks, let node = nodes.popLast() {
            if let link = link(from: node), links.contains(where: { $0.id == link.id }) == false {
                links.append(link)
            }

            if let content = node.content {
                nodes.append(contentsOf: content)
            }
        }

        return links.sorted { lhs, rhs in
            lhs.fileName.localizedStandardCompare(rhs.fileName) == .orderedAscending
        }
    }

    private static func metadata(
        forLinkAt index: Substring.Index,
        fallbackID: String,
        fallbackPath: String,
        in html: String
    ) -> AttachmentHTMLMetadata {
        guard let scope = metadataScope(forLinkAt: index, in: html) else {
            return AttachmentHTMLMetadata()
        }

        var metadata = AttachmentHTMLMetadata(
            id: attribute("data-attachment-id", in: scope),
            fileName: attribute("data-attachment-name", in: scope)?.removingPercentEncoding,
            path: attribute("data-attachment-url", in: scope),
            mimeType: attribute("data-attachment-mime", in: scope),
            fileSize: attribute("data-attachment-size", in: scope).flatMap(Int.init)
        )

        if let metadataID = metadata.id, metadataID != fallbackID {
            metadata.id = nil
            metadata.fileName = nil
            metadata.path = nil
            metadata.mimeType = nil
            metadata.fileSize = nil
        }

        if let metadataPath = metadata.path, metadataPath != fallbackPath {
            metadata.fileName = nil
            metadata.path = nil
            metadata.mimeType = nil
            metadata.fileSize = nil
        }

        return metadata
    }

    private static func metadataScope(
        forLinkAt index: Substring.Index,
        in html: String
    ) -> String? {
        if let sameTagScope = sameTagMetadataScope(forLinkAt: index, in: html) {
            return sameTagScope
        }

        var searchUpperBound = index
        while let start = html[..<searchUpperBound].range(of: "<", options: .backwards)?.lowerBound {
            let close = html[start...].firstIndex(of: ">") ?? html.endIndex
            let tag = String(html[start...close])
            if tag.hasPrefix("</") == false, tag.contains("data-attachment-") {
                return tag
            }
            searchUpperBound = start
        }

        return nil
    }

    private static func sameTagMetadataScope(
        forLinkAt index: Substring.Index,
        in html: String
    ) -> String? {
        guard
            let start = html[..<index].range(of: "<", options: .backwards)?.lowerBound,
            let close = html[start...].firstIndex(of: ">"),
            close >= index
        else {
            return nil
        }

        let tag = String(html[start...close])
        return tag.contains("data-attachment-") ? tag : nil
    }

    private static func attribute(_ name: String, in html: String) -> String? {
        for quote in ["\"", "'"] {
            let marker = "\(name)=\(quote)"
            guard let start = html.range(of: marker)?.upperBound else { continue }
            let tail = html[start...]
            guard let end = tail.firstIndex(of: Character(quote)) else { continue }
            let value = String(tail[..<end])
            return value.isEmpty ? nil : value
        }
        return nil
    }

    private static func link(from node: ProseMirrorNode) -> DocmostAttachmentLink? {
        guard let attrs = node.attrs else { return nil }

        let source = stringAttribute(["url", "src"], in: attrs)
        let attachmentID = stringAttribute(["attachmentId", "data-attachment-id"], in: attrs)
            ?? source.flatMap(docmostAttachmentID)
        guard let attachmentID, isSafeSegment(attachmentID) else { return nil }

        let fileName = stringAttribute(["name", "fileName", "title"], in: attrs)
            ?? source.flatMap(fileNameFromDocmostPath)
        guard let fileName, isSafeFileName(fileName) else { return nil }

        let path = source.flatMap { $0.hasPrefix("/api/files/") ? $0 : nil }
            ?? DocmostAttachmentLink.path(id: attachmentID, fileName: fileName)

        return DocmostAttachmentLink(
            id: attachmentID,
            fileName: fileName,
            path: path,
            fileSize: intAttribute(["size", "fileSize"], in: attrs),
            mimeType: stringAttribute(["mime", "mimeType"], in: attrs)
        )
    }

    private static func stringAttribute(_ keys: [String], in attrs: [String: ProseMirrorJSONValue]) -> String? {
        for key in keys {
            guard let value = attrs[key]?.stringValue, value.isEmpty == false else { continue }
            return value
        }
        return nil
    }

    private static func intAttribute(_ keys: [String], in attrs: [String: ProseMirrorJSONValue]) -> Int? {
        for key in keys {
            guard let value = attrs[key]?.intValue else { continue }
            return value
        }
        return nil
    }

    private static func docmostAttachmentID(from source: String) -> String? {
        guard source.hasPrefix("/api/files/") else { return nil }
        let suffix = source.dropFirst("/api/files/".count)
        return suffix.split(separator: "/", maxSplits: 1).first.map(String.init)
    }

    private static func fileNameFromDocmostPath(_ source: String) -> String? {
        guard source.hasPrefix("/api/files/") else { return nil }
        let suffix = source.dropFirst("/api/files/".count)
        let parts = suffix.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }
        return String(parts[1]).removingPercentEncoding ?? String(parts[1])
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

private struct AttachmentHTMLMetadata {
    var id: String?
    var fileName: String?
    var path: String?
    var mimeType: String?
    var fileSize: Int?
}
