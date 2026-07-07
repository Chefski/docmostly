import Foundation

nonisolated enum NativeEditorWebURLPolicy {
    static func webURL(from source: String?) -> URL? {
        guard let url = trimmedURL(from: source),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https"
        else {
            return nil
        }

        return url
    }

    static func documentResourceURL(from source: String?, serverURLString: String?) -> URL? {
        guard let source = source?.trimmingCharacters(in: .whitespacesAndNewlines),
              source.isEmpty == false,
              let serverURLString,
              let serverURL = URL(string: serverURLString),
              let serverScheme = serverURL.scheme?.lowercased(),
              serverScheme == "http" || serverScheme == "https",
              serverURL.host() != nil
        else {
            return nil
        }

        let candidateURL: URL?
        if let absoluteURL = URL(string: source), absoluteURL.scheme?.isEmpty == false {
            candidateURL = absoluteURL
        } else {
            candidateURL = URL(string: source, relativeTo: serverURL)?.absoluteURL
        }

        guard let candidateURL, sameOrigin(candidateURL, as: serverURL) else {
            return nil
        }

        return candidateURL
    }

    static func allowsNavigation(to url: URL?, allowedHosts: Set<String>) -> Bool {
        guard let url else { return true }

        let scheme = url.scheme?.lowercased()
        if scheme == "about" {
            return true
        }

        guard scheme == "http" || scheme == "https",
              let host = url.host()?.lowercased()
        else {
            return false
        }

        return allowedHosts.contains(host)
    }

    private static func trimmedURL(from source: String?) -> URL? {
        guard let source = source?.trimmingCharacters(in: .whitespacesAndNewlines),
              source.isEmpty == false
        else {
            return nil
        }

        return URL(string: source)
    }

    private static func sameOrigin(_ url: URL, as serverURL: URL) -> Bool {
        url.scheme?.lowercased() == serverURL.scheme?.lowercased()
            && url.host()?.lowercased() == serverURL.host()?.lowercased()
            && url.port == serverURL.port
    }
}
