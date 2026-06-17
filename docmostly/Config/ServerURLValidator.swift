import Foundation

nonisolated enum ServerURLValidationError: Error, Equatable, LocalizedError {
    case empty
    case malformed
    case unsupportedScheme
    case missingHost

    var errorDescription: String? {
        switch self {
        case .empty:
            "Enter a Docmost server URL."
        case .malformed:
            "Enter a valid server URL."
        case .unsupportedScheme:
            "Use an HTTPS or HTTP server URL."
        case .missingHost:
            "The server URL needs a host name."
        }
    }
}

nonisolated enum ServerURLValidator {
    static func normalizedURL(from rawValue: String) throws -> URL {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw ServerURLValidationError.empty
        }

        let valueWithScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard var components = URLComponents(string: valueWithScheme) else {
            throw ServerURLValidationError.malformed
        }

        guard let scheme = components.scheme?.lowercased() else {
            throw ServerURLValidationError.unsupportedScheme
        }

        guard scheme == "https" || scheme == "http" else {
            throw ServerURLValidationError.unsupportedScheme
        }

        guard components.host?.isEmpty == false else {
            throw ServerURLValidationError.missingHost
        }

        components.scheme = scheme
        components.path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.query = nil
        components.fragment = nil

        guard let normalized = components.url else {
            throw ServerURLValidationError.malformed
        }

        return normalized
    }
}
