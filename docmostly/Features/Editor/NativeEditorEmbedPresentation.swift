import Foundation

nonisolated extension NativeEditorEmbedBlock {
    var displayProvider: String {
        NativeEditorEmbedResolver.provider(source: source, explicitProvider: provider)
    }

    var youtubePlayerSource: String? {
        NativeEditorEmbedResolver.youtubeWatchSource(from: source)
    }

    var spotifyEmbedURL: URL? {
        NativeEditorEmbedResolver.spotifyEmbedURL(from: source)
    }
}

nonisolated enum NativeEditorEmbedResolver {
    static func provider(source: String?, explicitProvider: String?) -> String {
        if let sourceProvider = inferredProvider(from: source) {
            return sourceProvider
        }

        let trimmedProvider = explicitProvider?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedProvider?.isEmpty == false ? trimmedProvider ?? "Embed" : "Embed"
    }

    static func youtubeWatchSource(from source: String?) -> String? {
        guard let videoID = youtubeVideoID(from: source) else { return nil }
        return "https://www.youtube.com/watch?v=\(videoID)"
    }

    static func spotifyEmbedURL(from source: String?) -> URL? {
        guard
            let source,
            var components = URLComponents(string: source),
            let host = components.host?.lowercased(),
            host == "open.spotify.com" || host == "www.open.spotify.com"
        else {
            return nil
        }

        components.scheme = "https"
        components.host = "open.spotify.com"

        let pathComponents = components.path.split(separator: "/").map(String.init)
        guard pathComponents.count >= 2 else { return nil }

        if pathComponents.first != "embed" {
            components.path = "/embed/" + pathComponents.prefix(2).joined(separator: "/")
        }

        return components.url
    }

    private static func inferredProvider(from source: String?) -> String? {
        if youtubeVideoID(from: source) != nil {
            return "YouTube"
        }

        if spotifyEmbedURL(from: source) != nil {
            return "Spotify"
        }

        return nil
    }

    private static func youtubeVideoID(from source: String?) -> String? {
        guard
            let source,
            let components = URLComponents(string: source),
            let host = components.host?.lowercased()
        else {
            return nil
        }

        let normalizedHost = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        if normalizedHost == "youtu.be" {
            return nonEmptyVideoID(String(components.path.dropFirst()))
        }

        guard normalizedHost == "youtube.com" || normalizedHost == "youtube-nocookie.com" else {
            return nil
        }

        if components.path.hasPrefix("/embed/") {
            return nonEmptyVideoID(String(components.path.dropFirst("/embed/".count)))
        }

        if components.path == "/watch" {
            return components.queryItems?.first { $0.name == "v" }?.value.flatMap(nonEmptyVideoID)
        }

        return nil
    }

    private static func nonEmptyVideoID(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }
}
