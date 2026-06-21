import Foundation

nonisolated enum SpaceLogoURL {
    static func url(logo: String?, serverURLString: String) -> URL? {
        guard let logo else { return nil }

        let trimmedLogo = logo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedLogo.isEmpty == false else { return nil }

        if let absoluteURL = URL(string: trimmedLogo),
           let scheme = absoluteURL.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            return absoluteURL
        }

        guard let baseURL = try? ServerURLValidator.normalizedURL(from: serverURLString) else {
            return nil
        }

        return baseURL
            .appending(path: AppConfig.apiPathPrefix)
            .appending(path: "attachments")
            .appending(path: "img")
            .appending(path: "space-icon")
            .appending(path: trimmedLogo)
    }
}
