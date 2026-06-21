import Foundation
import UniformTypeIdentifiers

actor DocmostAPIClient {
    nonisolated let baseURL: URL
    private let loader: any HTTPDataLoading
    private let decoder: JSONDecoder
    private let cookieJar: SessionCookieJar?

    init(
        baseURL: URL,
        loader: any HTTPDataLoading = DocmostURLSessionFactory.makeAPIURLSession(),
        decoder: JSONDecoder = DocmostJSONDecoder.make(),
        cookieJar: SessionCookieJar? = nil
    ) {
        self.baseURL = baseURL
        self.loader = loader
        self.decoder = decoder
        self.cookieJar = cookieJar
    }

    func send<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type = T.self) async throws -> T {
        let endpointRequest = try endpoint.urlRequest(baseURL: baseURL)
        let request = await authenticatedRequest(endpointRequest)
        let (data, response) = try await loader.data(for: request)
        await ingestCookies(from: response, requestURL: request.url)
        try validate(response: response, data: data)

        do {
            let envelope = try decoder.decode(APIEnvelope<T>.self, from: data)
            return envelope.data
        } catch {
            throw APIError.connectionFailed(error.localizedDescription)
        }
    }

    func sendVoid(_ endpoint: Endpoint) async throws {
        let endpointRequest = try endpoint.urlRequest(baseURL: baseURL)
        let request = await authenticatedRequest(endpointRequest)
        let (data, response) = try await loader.data(for: request)
        await ingestCookies(from: response, requestURL: request.url)
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
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "multipart/form-data; boundary=\(multipartBody.boundary)",
            forHTTPHeaderField: "Content-Type"
        )
        request.setValue(multipartBody.contentLength.description, forHTTPHeaderField: "Content-Length")

        request = await authenticatedRequest(request)
        let (data, response) = try await loader.upload(for: request, fromFile: multipartBody.fileURL)
        await ingestCookies(from: response, requestURL: request.url)
        try validate(response: response, data: data)
        return try decodeUploadResponse(from: data)
    }

    private func authenticatedRequest(_ request: URLRequest) async -> URLRequest {
        var request = request
        request.httpShouldHandleCookies = false
        guard
            let cookieJar,
            let url = request.url,
            let cookieHeader = await cookieJar.cookieHeader(for: url)
        else {
            return request
        }
        request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        return request
    }

    private func ingestCookies(from response: URLResponse, requestURL: URL?) async {
        guard
            let cookieJar,
            let requestURL,
            let httpResponse = response as? HTTPURLResponse
        else {
            return
        }
        await cookieJar.ingestCookies(from: httpResponse, requestURL: requestURL)
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
