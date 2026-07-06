import Foundation

nonisolated enum DocmostImageAttachmentType: String {
    case spaceIcon = "space-icon"
    case workspaceIcon = "workspace-icon"
}

nonisolated enum SpaceLogoURL {
    static func url(
        logo: String?,
        serverURLString: String,
        type: DocmostImageAttachmentType = .spaceIcon
    ) -> URL? {
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
            .appending(path: type.rawValue)
            .appending(path: trimmedLogo)
    }
}
