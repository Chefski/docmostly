import Foundation
import UniformTypeIdentifiers

actor DocmostAPIClient {
    nonisolated static let maximumResponseBytes = DocmostResponseSizeLimit.maximumBytes
    nonisolated static let maximumExportResponseBytes = DocmostResponseSizeLimit.maximumExportBytes

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
        try validateResponseSize(data)
        try validate(response: response, data: data)

        do {
            let envelope = try DocmostJSONDecoder.decode(APIEnvelope<T>.self, from: data, using: decoder)
            return envelope.data
        } catch {
            throw APIError.decodingFailed(error.localizedDescription)
        }
    }

    func sendVoid(_ endpoint: Endpoint) async throws {
        let endpointRequest = try endpoint.urlRequest(baseURL: baseURL)
        let request = await authenticatedRequest(endpointRequest)
        let (data, response) = try await loader.data(for: request)
        await ingestCookies(from: response, requestURL: request.url)
        try validateResponseSize(data)
        try validate(response: response, data: data)
    }

    func loadImageData(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpShouldHandleCookies = false
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        request = await authenticatedRequest(request)

        let (data, response) = try await loader.data(for: request)
        await ingestCookies(from: response, requestURL: request.url)
        try validateResponseSize(data)
        try validate(response: response, data: data)
        return data
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
        try validateResponseSize(data)
        try validate(response: response, data: data)
        return try decodeUploadResponse(from: data)
    }

    func exportPage(
        pageId: String,
        format: DocmostPageExportFormat,
        includeChildren: Bool = false,
        includeAttachments: Bool = false
    ) async throws -> DocmostPageExportFile {
        let endpointRequest = try Endpoint.exportPage(
            pageId: pageId,
            format: format,
            includeChildren: includeChildren,
            includeAttachments: includeAttachments
        ).urlRequest(baseURL: baseURL)
        let request = await authenticatedRequest(endpointRequest)
        let (data, response) = try await loader.data(for: request, maximumBytes: Self.maximumExportResponseBytes)
        await ingestCookies(from: response, requestURL: request.url)
        try validateResponseSize(data, maximumBytes: Self.maximumExportResponseBytes)
        try validate(response: response, data: data)

        let httpResponse = response as? HTTPURLResponse
        return DocmostPageExportFile(
            data: data,
            fileName: Self.exportFileName(
                from: httpResponse?.value(forHTTPHeaderField: "Content-Disposition"),
                fallbackExtension: format.defaultFilenameExtension
            ),
            mimeType: httpResponse?.value(forHTTPHeaderField: "Content-Type")
        )
    }

    func importPage(fileURL: URL, spaceId: String) async throws -> DocmostPage {
        let mimeType = Self.mimeType(for: fileURL)
        let fileName = fileURL.lastPathComponent.isEmpty ? "import" : fileURL.lastPathComponent
        let multipartBody = try MultipartFormDataWriter.writeBody(
            fields: [MultipartFormDataField(name: "spaceId", value: spaceId)],
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

        var request = URLRequest(url: importPageURL)
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
        try validateResponseSize(data)
        try validate(response: response, data: data)
        return try decodeImportResponse(from: data)
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

    private func validateResponseSize(_ data: Data) throws {
        try validateResponseSize(data, maximumBytes: Self.maximumResponseBytes)
    }

    private func validateResponseSize(_ data: Data, maximumBytes: Int) throws {
        guard data.count <= maximumBytes else {
            throw APIError.responseTooLarge
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

    private var importPageURL: URL {
        baseURL
            .appending(path: AppConfig.apiPathPrefix)
            .appending(path: "pages/import")
    }

    private func decodeUploadResponse(from data: Data) throws -> DocmostAttachment {
        do {
            return try DocmostJSONDecoder.decode(DocmostAttachment.self, from: data, using: decoder)
        } catch {
            do {
                return try DocmostJSONDecoder.decode(
                    APIEnvelope<DocmostAttachment>.self,
                    from: data,
                    using: decoder
                ).data
            } catch {
                throw APIError.decodingFailed(error.localizedDescription)
            }
        }
    }

    private func decodeImportResponse(from data: Data) throws -> DocmostPage {
        do {
            return try DocmostJSONDecoder.decode(APIEnvelope<DocmostPage>.self, from: data, using: decoder).data
        } catch {
            do {
                return try DocmostJSONDecoder.decode(DocmostPage.self, from: data, using: decoder)
            } catch {
                throw APIError.decodingFailed(error.localizedDescription)
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

    private static func exportFileName(from contentDisposition: String?, fallbackExtension: String) -> String {
        guard let contentDisposition else {
            return "docmost-page.\(fallbackExtension)"
        }

        let fields = contentDisposition
            .split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        if let encodedName = fields.compactMap({ field -> String? in
            guard field.lowercased().hasPrefix("filename*=") else { return nil }
            let value = field.dropFirst("filename*=".count)
            let components = String(value).split(separator: "'", omittingEmptySubsequences: false)
            guard components.count >= 3 else {
                return String(value)
            }
            return components.dropFirst(2).joined(separator: "'")
        }).first {
            return encodedName.removingPercentEncoding ?? encodedName
        }

        if let fileName = fields.compactMap({ field -> String? in
            guard field.lowercased().hasPrefix("filename=") else { return nil }
            return String(field.dropFirst("filename=".count)).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }).first {
            return fileName.removingPercentEncoding ?? fileName
        }

        return "docmost-page.\(fallbackExtension)"
    }
}
