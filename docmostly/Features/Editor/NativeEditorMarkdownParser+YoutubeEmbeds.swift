import Foundation

extension NativeEditorMarkdownParser {
    static func youtubeHTMLBlock(
        in lines: [String],
        startingAt index: Array<String>.Index
    ) -> (block: NativeEditorBlock, endIndex: Array<String>.Index)? {
        guard
            let attributes = htmlTagAttributes(from: lines[index], tagName: "div"),
            attributes.keys.contains("data-youtube-video")
        else {
            return nil
        }

        var currentIndex = index
        var containerDepth = 0
        var iframeLines: [String] = []
        var iframeAttributes: [String: String]?

        while currentIndex < lines.endIndex {
            let line = lines[currentIndex].trimmingCharacters(in: .whitespacesAndNewlines)

            if iframeAttributes == nil {
                if iframeLines.isEmpty == false {
                    iframeLines.append(line)
                    iframeAttributes = youtubeIframeAttributes(from: iframeLines)
                } else if let attributes = firstHTMLTagAttributes(in: line, tagName: "iframe") {
                    iframeAttributes = attributes
                } else if line.localizedCaseInsensitiveContains("<iframe") {
                    iframeLines = [line]
                    iframeAttributes = youtubeIframeAttributes(from: iframeLines)
                }
            }

            containerDepth += htmlTagDepthDelta(in: line, tagName: "div")
            if containerDepth <= 0 {
                guard let iframeAttributes,
                      let block = youtubeBlock(from: iframeAttributes) else {
                    return nil
                }
                return (block, lines.index(after: currentIndex))
            }

            currentIndex = lines.index(after: currentIndex)
        }

        return nil
    }

    static func youtubeHTMLMarkdown(from node: ProseMirrorNode?) -> String? {
        guard
            let node,
            node.type == "youtube",
            let source = node.attrs?["src"]?.stringValue,
            let embedSource = youtubeEmbedSource(from: source, start: node.attrs?["start"]?.intValue)
        else {
            return nil
        }

        let frameTag = youtubeHTMLTag("iframe", attributes: [
            ("src", embedSource),
            ("width", node.attrs?["width"]?.displayString),
            ("height", node.attrs?["height"]?.displayString)
        ])

        return """
        <div data-youtube-video="">
        \(frameTag)</iframe>
        </div>
        """
    }

    private static func youtubeIframeAttributes(from lines: [String]) -> [String: String]? {
        let html = lines.joined(separator: " ")
        guard html.contains(">") else { return nil }
        return firstHTMLTagAttributes(in: html, tagName: "iframe")
    }

    private static func youtubeBlock(from iframeAttributes: [String: String]) -> NativeEditorBlock? {
        guard
            let source = youtubeNonEmptyHTMLAttribute(iframeAttributes["src"]),
            let youtube = youtubeSourceAttributes(from: source)
        else {
            return nil
        }

        let width = youtubeNonEmptyHTMLAttribute(iframeAttributes["width"]).flatMap(Int.init)
        let height = youtubeNonEmptyHTMLAttribute(iframeAttributes["height"]).flatMap(Int.init)
        let embed = NativeEditorEmbedBlock(
            source: youtube.source,
            provider: "YouTube",
            alignment: nil,
            width: width.map(String.init),
            height: height.map(String.init)
        )
        var attrs: [String: ProseMirrorJSONValue] = ["src": .string(youtube.source)]
        if let start = youtube.start {
            attrs["start"] = .int(start)
        }
        if let width {
            attrs["width"] = .int(width)
        }
        if let height {
            attrs["height"] = .int(height)
        }

        return NativeEditorBlock(
            kind: .embed(embed),
            text: AttributedString(NativeEditorDocument.previewText(for: .embed(embed))),
            alignment: .left,
            rawNode: ProseMirrorNode(type: "youtube", attrs: attrs)
        )
    }

    private static func youtubeSourceAttributes(from source: String) -> (source: String, start: Int?)? {
        guard let components = URLComponents(string: source),
              let host = components.host?.lowercased() else {
            return nil
        }

        let normalizedHost = host.hasPrefix("www.") ? String(host.dropFirst("www.".count)) : host
        let videoID: String?
        if normalizedHost == "youtu.be" {
            videoID = youtubeNonEmptyHTMLAttribute(String(components.percentEncodedPath.dropFirst()))
        } else if normalizedHost == "youtube.com" || normalizedHost == "youtube-nocookie.com" {
            videoID = youtubeVideoID(from: components)
        } else {
            videoID = nil
        }

        guard let videoID else { return nil }
        let start = components.queryItems?.first { $0.name == "start" }?.value.flatMap(Int.init)
        return ("https://www.youtube.com/watch?v=\(videoID)", start)
    }

    private static func youtubeVideoID(from components: URLComponents) -> String? {
        if components.percentEncodedPath.hasPrefix("/embed/") {
            return youtubeNonEmptyHTMLAttribute(String(components.percentEncodedPath.dropFirst("/embed/".count)))
        }

        if components.percentEncodedPath == "/watch" {
            return components.queryItems?.first { $0.name == "v" }?.value.flatMap(youtubeNonEmptyHTMLAttribute)
        }

        return nil
    }

    private static func youtubeEmbedSource(from source: String, start: Int?) -> String? {
        guard let youtube = youtubeSourceAttributes(from: source),
              let components = URLComponents(string: youtube.source),
              let videoID = components.queryItems?.first(where: { $0.name == "v" })?.value,
              videoID.isEmpty == false else {
            return nil
        }

        var embedSource = "https://www.youtube-nocookie.com/embed/\(videoID)"
        if let start, start > 0 {
            embedSource += "?start=\(start)"
        }
        return embedSource
    }

    private static func youtubeHTMLTag(_ name: String, attributes: [(String, String?)]) -> String {
        let attributeText = attributes.compactMap { key, value -> String? in
            guard let value = youtubeNonEmptyHTMLAttribute(value) else { return nil }
            return #"\#(key)="\#(escapedInlineHTMLAttribute(value))""#
        }.joined(separator: " ")

        return attributeText.isEmpty ? "<\(name)>" : "<\(name) \(attributeText)>"
    }

    private static func youtubeNonEmptyHTMLAttribute(_ value: String?) -> String? {
        guard let value, value.isEmpty == false else {
            return nil
        }
        return value
    }
}
