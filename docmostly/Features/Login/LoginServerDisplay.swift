import Foundation

nonisolated enum LoginServerDisplay {
    static func title(for serverURLString: String) -> String {
        guard let url = URL(string: serverURLString), let host = url.host(), host.isEmpty == false else {
            return serverURLString.isEmpty ? "Docmost workspace" : serverURLString
        }

        return host
    }

    static func subtitle(for serverURLString: String) -> String {
        guard let url = URL(string: serverURLString) else {
            return serverURLString
        }

        return url.absoluteString
    }
}
