import Foundation

nonisolated enum APIError: Error, LocalizedError, Equatable {
    case invalidResponse
    case httpStatus(Int, String?)
    case missingData
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The server returned an invalid response."
        case .httpStatus(let status, let message):
            message ?? "The server returned HTTP \(status)."
        case .missingData:
            "The server response did not include expected data."
        case .connectionFailed(let message):
            message
        }
    }
}
