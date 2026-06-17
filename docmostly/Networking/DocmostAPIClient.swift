import Foundation
import UniformTypeIdentifiers

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

    func uploadFile(fileURL: URL, pageId: String, attachmentId: String? = nil) async throws -> DocmostAttachment {
        let mimeType = Self.mimeType(for: fileURL)
        let fileName = fileURL.lastPathComponent.isEmpty ? "file" : fileURL.lastPathComponent
        var fields = [MultipartFormDataField(name: "pageId", value: pageId)]
        if let attachmentId {
            fields.append(MultipartFormDataField(name: "attachmentId", value: attachmentId))
        }

        let multipartBody = try MultipartFormDataWriter.writeBody(
            fields: fields,
            file: MultipartFormDataFile(
                fieldName: "file",
                fileURL: fileURL,
                fileName: fileName,
                mimeType: mimeType
            )
        )
        defer {
            try? FileManager.default.removeItem(at: multipartBody.fileURL)
        }

        var request = URLRequest(url: uploadFileURL)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = true
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "multipart/form-data; boundary=\(multipartBody.boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue(multipartBody.contentLength.description, forHTTPHeaderField: "Content-Length")

        let (data, response) = try await loader.upload(for: request, fromFile: multipartBody.fileURL)
        try validate(response: response, data: data)
        return try decodeUploadResponse(from: data)
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

    private var uploadFileURL: URL {
        baseURL
            .appending(path: AppConfig.apiPathPrefix)
            .appending(path: "files/upload")
    }

    private func decodeUploadResponse(from data: Data) throws -> DocmostAttachment {
        do {
            return try decoder.decode(DocmostAttachment.self, from: data)
        } catch {
            do {
                return try decoder.decode(APIEnvelope<DocmostAttachment>.self, from: data).data
            } catch {
                throw APIError.connectionFailed(error.localizedDescription)
            }
        }
    }

    private static func mimeType(for fileURL: URL) -> String {
        let pathExtension = fileURL.pathExtension
        guard pathExtension.isEmpty == false else {
            return "application/octet-stream"
        }

        return UTType(filenameExtension: pathExtension)?.preferredMIMEType ?? "application/octet-stream"
    }
}
