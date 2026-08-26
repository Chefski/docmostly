import Foundation

extension AppState {
    func loadAuthenticatedImageData(from url: URL) async throws -> Data {
        guard let apiClient else {
            throw APIError.connectionFailed("Images require a network connection.")
        }
        return try await apiClient.loadImageData(from: url)
    }
}
