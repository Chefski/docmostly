import Foundation

extension AppState {
    func loadCollaborationToken() async throws -> CollaborationTokenResponse {
        guard let apiClient else {
            throw APIError.connectionFailed("Realtime collaboration requires a network connection.")
        }

        return try await apiClient.send(.collabToken)
    }

    func collaborationWebSocketURL() throws -> URL {
        let serverURL = try ServerURLValidator.normalizedURL(from: serverURLString)
        return try NativeEditorCollaborationEndpoint.webSocketURL(serverBaseURL: serverURL)
    }

    func realtimeEventWebSocketURL() throws -> URL {
        let serverURL = try ServerURLValidator.normalizedURL(from: serverURLString)
        return try NativeEditorRealtimeEventEndpoint.webSocketURL(serverBaseURL: serverURL)
    }
}
