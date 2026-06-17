import Foundation

actor DocmostAPIClient {
    nonisolated let baseURL: URL
    private let loader: any HTTPDataLoading
    private let decoder: JSONDecoder

    init(
        baseURL: URL,
        loader: any HTTPDataLoading = URLSession.shared,
        decoder: JSONDecoder = DocmostJSONDecoder.make()
    ) {
        self.baseURL = baseURL
        self.loader = loader
        self.decoder = decoder
    }

    func send<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type = T.self) async throws -> T {
        let request = try endpoint.urlRequest(baseURL: baseURL)
        let (data, response) = try await loader.data(for: request)
        try validate(response: response, data: data)

        do {
            let envelope = try decoder.decode(APIEnvelope<T>.self, from: data)
            return envelope.data
        } catch {
            throw APIError.connectionFailed(error.localizedDescription)
        }
    }

    func sendVoid(_ endpoint: Endpoint) async throws {
        let request = try endpoint.urlRequest(baseURL: baseURL)
        let (data, response) = try await loader.data(for: request)
        try validate(response: response, data: data)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            let message = decodeErrorMessage(from: data)
            throw APIError.httpStatus(httpResponse.statusCode, message)
        }
    }

    private func decodeErrorMessage(from data: Data) -> String? {
        guard data.isEmpty == false else { return nil }
        guard
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let message = object["message"] as? String
        else {
            return nil
        }
        return message
    }
}
