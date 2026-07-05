import Foundation
import Testing
@testable import docmostly

@MainActor
struct DocmostAPIClientPageTransferTests {
    @Test func exportPageReturnsRawFileAndDecodedFilename() async throws {
        let loader = CapturingHTTPDataLoader(responses: [
            .init(
                data: Data("# Roadmap".utf8),
                response: try response(
                    url: "https://docs.example.com/api/pages/export",
                    headers: [
                        "Content-Disposition": #"attachment; filename="Roadmap%20Plan.md""#,
                        "Content-Type": "text/markdown"
                    ]
                )
            )
        ])
        let client = DocmostAPIClient(baseURL: URL(string: "https://docs.example.com")!, loader: loader)

        let file = try await client.exportPage(pageId: "page-1", format: .markdown, includeChildren: true)
        let requests = await loader.dataRequests
        guard let request = requests.first else {
            Issue.record("Expected export request.")
            return
        }
        guard let bodyData = request.httpBody,
              let body = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            Issue.record("Expected JSON export request body.")
            return
        }

        #expect(request.url?.absoluteString == "https://docs.example.com/api/pages/export")
        #expect(body["pageId"] as? String == "page-1")
        #expect(body["format"] as? String == "markdown")
        #expect(body["includeChildren"] as? Bool == true)
        #expect(file.fileName == "Roadmap Plan.md")
        #expect(String(data: file.data, encoding: .utf8) == "# Roadmap")
    }

    @Test func importPageUploadsMultipartSpaceAndFile() async throws {
        let sourceURL = URL.temporaryDirectory.appending(path: "docmostly-import-\(UUID().uuidString).md")
        try "# Imported".write(to: sourceURL, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: sourceURL)
        }

        let loader = CapturingHTTPDataLoader(responses: [
            .init(
                data: Data("""
                {
                  "data": {
                    "id": "page-1",
                    "slugId": "imported-slug",
                    "title": "Imported",
                    "spaceId": "space-1"
                  },
                  "success": true,
                  "status": 200
                }
                """.utf8),
                response: try response(url: "https://docs.example.com/api/pages/import")
            )
        ])
        let client = DocmostAPIClient(baseURL: URL(string: "https://docs.example.com")!, loader: loader)

        let page = try await client.importPage(fileURL: sourceURL, spaceId: "space-1")
        let requests = await loader.uploadRequests
        guard let request = requests.first else {
            Issue.record("Expected import upload request.")
            return
        }
        guard let contentType = request.value(forHTTPHeaderField: "Content-Type") else {
            Issue.record("Expected multipart content type.")
            return
        }

        #expect(request.url?.absoluteString == "https://docs.example.com/api/pages/import")
        #expect(contentType.hasPrefix("multipart/form-data; boundary="))
        #expect(page.id == "page-1")
        #expect(page.slugId == "imported-slug")
    }

    private func response(
        url: String,
        headers: [String: String] = [:]
    ) throws -> HTTPURLResponse {
        guard let url = URL(string: url) else {
            throw APIError.connectionFailed("Invalid test URL.")
        }
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: 200,
            httpVersion: nil,
            headerFields: headers
        ) else {
            throw APIError.invalidResponse
        }
        return response
    }
}
